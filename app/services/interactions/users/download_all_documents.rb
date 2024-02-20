module Interactions
  module Users
    class DownloadAllDocuments
      attr_reader :user

      def initialize(user, url_key, user_document_connection_id=nil, company_id=nil, admin_email=nil)
        @user = user
        @url_key = url_key
        @file_names = []
        @file_presence_count = 0
        @user_document_connection_id = user_document_connection_id
        @company = Company.find_by(id: company_id) rescue nil
        @admin_email = admin_email
        @secure_token = SecureRandom.urlsafe_base64(16)
      end

      def perform
        Dir.mktmpdir do |tmpdir|
          file_path = "#{tmpdir}/#{zip_filename}.zip"
          file_path = "public/#{zip_filename}.zip" if ENV['RAILS_ENV'] == 'development' || ENV['RAILS_ENV'] == 'test'
          Zip::File.open(file_path, Zip::File::CREATE) do |zip|
            unless @user_document_connection_id.present?
              users.each do |user|
                user.paperwork_requests.each do |paperwork|
                  paperwork_type = paperwork.paperwork_packet_id ? 'paperwork_packet' : 'paperwork_request'
                  filename = pdf_filename(paperwork_type, paperwork)
                  download_url = paperwork_download_url(paperwork, filename)
                  if download_url.present?
                    tempfile = download_temp_file(download_url, tmpdir)
                    zip.add(filename, tempfile.path)
                  end
                end

                user.personal_documents.each do |personal_document|
                  filename = pdf_filename('personal_document', personal_document)
                  download_url = personal_document_download_url(personal_document, filename)

                  if download_url.present?
                    tempfile = download_temp_file(download_url, tmpdir)
                    zip.add(filename, tempfile.path)
                  end
                end

                user_document_connections = UserDocumentConnection.where(user_id: user.id, state: 'completed')
                user_document_connections.each do |user_document_connection|
                  if user_document_connection.attached_files.present?
                    user_document_connection.attached_files.each do |attached_file|
                      filename = pdf_filename('upload_request', attached_file)
                      download_url = upload_request_download_url(attached_file, filename)

                      if download_url.present?
                        tempfile = download_temp_file(download_url, tmpdir)
                        zip.add(filename, tempfile.path)
                      end
                    end
                  end
                end
              end if users.present?
            else @user_document_connection_id.present?
              user_document_connections = UserDocumentConnection.where(id: @user_document_connection_id)
              user_document_connections.each do |user_document_connection|
                if user_document_connection.attached_files.present?
                  user_document_connection.attached_files.each do |attached_file|
                    filename = pdf_filename('upload_request', attached_file)
                    download_url = upload_request_download_url(attached_file, filename)

                    if download_url.present?
                      tempfile = download_temp_file(download_url, tmpdir)
                      zip.add(filename, tempfile.path)
                    end
                  end
                end
              end
            end
          end

          if ENV['RAILS_ENV'] == 'development' || ENV['RAILS_ENV'] == 'test'
            notify_firebase(nil, file_path.split('public/')[1])
          else
            s3_object = upload_zip_s3(file_path)
            notify_firebase(s3_object)
          end
        end
      end

      def pdf_filename(type, obj)
        obj_name = request_name(type, obj)
        case type
        when 'paperwork_request'
          if @company.present?
            "#{obj_name} #{signed(obj)}#{file_presence_count(obj_name)} - #{related_user_name(obj)}(#{obj.created_at.strftime('%d-%m-%Y')}).pdf"
          else
            "#{related_user_name(obj)} - #{obj_name} #{signed(obj)}#{file_presence_count(obj_name)}.pdf"
          end
        when 'paperwork_packet'
          if @company.present?
            "#{obj_name} #{signed(obj)}#{file_presence_count(obj_name)} - #{related_user_name(obj)}(#{obj.created_at.strftime('%d-%m-%Y')}).pdf"
          else
            "#{related_user_name(obj)} - #{obj_name} #{signed(obj)}#{file_presence_count(obj_name)}.pdf"
          end
        when 'upload_request'
          "#{obj_name} - #{related_user_name(obj)} (#{obj.created_at.strftime('%d-%m-%Y')})#{file_presence_count(obj_name)}#{request_extenstion(obj)}"

        when 'personal_document'
          obj.title + request_extenstion(obj)
        end
      end

      def paperwork_download_url(obj, filename)
        if obj.signed_document.present?
          obj.signed_document.download_url(filename)

        else
          obj.unsigned_document.download_url(filename)
        end
      end

      private
      def users
        @users ||= @company.present? ? @company.users : [@user]
      end

      def download_temp_file(download_url, tmpdir)
        File.open("#{tmpdir}/#{random_filename}", 'wb').tap do |file|
          if ENV['RAILS_ENV'] == 'development' || ENV['RAILS_ENV'] == 'test'
            File.read("public"+download_url)
          else
            file.write HTTParty.get(download_url).body
          end
        end
      end

      def random_filename
        "#{SecureRandom.urlsafe_base64}.pdf"
      end

      def upload_zip_s3(file_path)
        key = "documents/#{Rails.env}/#{Date.today.to_s}/#{zip_filename}.zip"
        object = Aws::S3::Resource.new(
          access_key_id: ENV['AWS_ACCESS_KEY'],
          secret_access_key: ENV['AWS_SECRET_KEY'],
          region: ENV['AWS_REGION']
        ).bucket(ENV['AWS_BUCKET']).object(key)

        object.upload_file(file_path, acl: 'private')
        object
      end

      def notify_firebase(s3_object, url=nil)
        url ||= s3_object.presigned_url(:get, expires_in: 3.hours.to_s.to_i)
        if @company.present?
          url = "http://#{@company.subdomain}.#{ENV['DEFAULT_HOST']}:3000/#{url}" if ENV['RAILS_ENV'] == 'development'
          url = "http://#{@company.subdomain}.#{ENV['DEFAULT_HOST']}:3001/#{url}" if ENV['RAILS_ENV'] == 'test'
          UserMailer.download_all_company_documents_email(@company.id, url, @admin_email).deliver_now!
        else
          firebase = Firebase::Client.new("#{ENV['FIREBASE_DATABASE_URL']}", ENV['FIREBASE_ADMIN_JSON'])
          firebase.set("download_documents/" + @url_key, url)
        end
      end

      def personal_document_download_url(obj, filename)
        obj.attached_file.file.download_url(filename)
      end

      def upload_request_download_url(obj, filename)
        obj.file.download_url(filename)
      end

      def file_presence_count(obj_name)
        presence = ""
        if @file_names.include?(obj_name)
          @file_presence_count += 1
          presence = "(#{@file_presence_count})"
        end
        @file_names.push obj_name
        presence
      end

      def request_name(type, obj)
        case type
        when 'paperwork_request'
          obj.document_with_deleted.try(:title)

        when 'paperwork_packet'
          packet_type(obj)

        when 'upload_request'
          request_name = obj.entity.document_connection_relation.title rescue nil
          request_name ||= "temp"
        end
      end

      def packet_type(obj)
        if obj.paperwork_packet_type == "bulk"
          obj.paperwork_packet_deleted.name + "(#{obj.template_ids.length})"

        else
          obj.document_with_deleted.try(:title)
        end
      end

      def signed(obj)
        if (obj.co_signer_id == nil && obj.state == "signed" )  || (obj.co_signer_id != nil && obj.state == "all_signed")
          if obj.sign_date
            obj.sign_date.strftime("%m-%d-%Y").to_s

          else
            Date.today.strftime("%m-%d-%Y").to_s
          end

        else
          "(Not Signed)"
        end
      end

      def related_user_name(obj)
        return obj.entity.user.full_name if obj.try(:entity_type).present?
        obj.user.full_name
      end

      def request_extenstion(obj)
        return File.extname(obj.original_filename) if obj.try(:entity_type).present?
        File.extname(obj.attached_file.original_filename)
      end

      def zip_filename
        if @user_document_connection_id.present?
          @zip_name ||= manage_file_name_length
        elsif @company.present?
          @zip_name ||= "#{@company.name} Documents (#{Time.now.in_time_zone(@company.time_zone).strftime("%m-%d-%Y").to_s})"
        else
          @zip_name ||= "#{user.preferred_full_name} Documents (#{Time.now.in_time_zone(user.company.time_zone).strftime("%m-%d-%Y").to_s})"
        end
        @zip_name.gsub(/\//,"") + " - #{@secure_token}"
      end

      def manage_file_name_length
        file_name = UserDocumentConnection.find_by(id: @user_document_connection_id).document_connection_relation.try(:title)
        if file_name&.length.to_i > 205
          file_name = (0..(file_name.length-1)/205).map{|i|file_name[i*205,205]}[0]
        end
        file_name
      end
    end
  end
end
