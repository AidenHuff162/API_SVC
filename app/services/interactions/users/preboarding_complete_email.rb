module Interactions
  module Users
    class PreboardingCompleteEmail
      attr_reader :user, :company, :zip_count

      def initialize(user)
        @user = user
        @company = user&.company
        @zip_count = 0        
      end

      def perform
        return unless company
        template = EmailTemplate.where(email_type: "preboarding", company_id: company.id).first
        if company.preboarding_complete_emails?
          if company.include_documents_preboarding
            zip_file_info = ActiveSupport::HashWithIndifferentAccess.new(get_completed_documents_zip_file())
            zip_count > 0 ? send_preboarding_email(user, template, zip_file_info['file_path'], zip_file_info['file_name']) : send_preboarding_email(user, template)
            delete_existing_file_if_any(zip_file_info['file_path'])
          else
            send_preboarding_email(user, template)
          end
        end
      end

      private

      def get_completed_documents_zip_file
        zip_filename = "#{user.full_name.gsub(' ', '_')}.zip"
        zip_file_path = File.join(get_file_path(), zip_filename)
        delete_existing_file_if_any(zip_file_path)
        
        completed_user_document_connections = user.user_document_connections.where(state: :completed)
        completed_paperwork_requests = user.paperwork_requests.where('(state = ? AND co_signer_id IS NULL) OR (state = ? AND co_signer_id IS NOT NULL)', 'signed', 'all_signed')

        Zip::File.open(zip_file_path, Zip::File::CREATE) do |zip|
          completed_paperwork_requests.try(:find_each) do |paperwork_request|
            next unless is_paperwork_request_completed(paperwork_request)
            filename = get_doc_filename(paperwork_request, 'paperwork_request')
            doc_download_url = get_doc_download_url(paperwork_request, filename)
            next unless doc_download_url
            tempfile = create_temp_file(doc_download_url, get_file_path(), filename)
            @zip_count += 1
            zip.add(filename, tempfile.path)
          end

          completed_user_document_connections.try(:find_each) do |udc|
            udc.attached_files.try(:find_each) do |udc_file|
              filename = get_doc_filename(udc, 'upload_request', udc_file)
              doc_download_url = get_doc_download_url(udc, filename, udc_file)
              next unless doc_download_url
              tempfile = create_temp_file(doc_download_url, get_file_path(), filename)
              @zip_count += 1
              zip.add(filename, tempfile.path)
            end
          end
        end

        { file_path: zip_file_path, file_name: zip_filename }
      end

      def get_file_path
        if Rails.env.development? || Rails.env.test?
          ("#{Rails.root}/tmp")
        else
          File.join(Dir.home, 'www/sapling/shared/')
        end
      end

      def get_doc_filename(document_object, document_type, udc_file = nil)
        doc_filename = ''
        case document_type.try(:downcase)
        when 'paperwork_request'
          if document_object.paperwork_packet_id && document_object.paperwork_packet.bulk?
            doc_filename = "#{document_object.paperwork_packet.name}#{rand(1000)}#{get_file_extension(document_object, document_type)}"
          else
            doc_filename = "#{document_object.document.try(:title)}#{rand(1000)}#{get_file_extension(document_object, document_type)}" 
          end
        when 'upload_request'
          doc_filename = "#{document_object.document_connection_relation.try(:title)}#{rand(1000)}#{get_file_extension(document_object, document_type, udc_file)}"
        end
        doc_filename.tr('/' , '_')
      end

      def get_doc_download_url(document_object, filename, udc_file = nil)
        doc_class_name = document_object.class.name.try(:downcase)
        case doc_class_name
        when 'paperworkrequest'
          document_object.signed_document.download_url(filename)
        when 'userdocumentconnection'
          udc_file.file.download_url(filename)
        end 
      end

      def create_temp_file(doc_download_url, file_path, file_name)
        file = File.join(file_path, file_name)
        File.open(file, 'wb+').tap do |file|
          if Rails.env.development? || Rails.env.test?
            File.read('public' + doc_download_url)
          else
            file.write(HTTParty.get(doc_download_url).body)
          end
        end
      end

      def delete_existing_file_if_any(zip_file_path)
        file = File.read(zip_file_path) rescue nil
        File.delete(zip_file_path) if file
      end

      def get_file_extension(document_object, document_type, udc_file = nil)
        filename =  case document_type.try(:downcase)
                    when 'paperwork_request'
                      document_object.signed_document.file.filename
                    when 'upload_request'
                      udc_file.original_filename
                    end
        File.extname(filename) if filename
      end

      def is_paperwork_request_completed(document_object)
        document_object.signed_document.present? && document_object.signed_document.file.present?
      end

      def send_preboarding_email(user, template, zip_file_url = nil, zip_filename = nil)
        UserMailer.preboarding_complete_email(user, template, zip_file_url, zip_filename).deliver_now!
      end
    end
  end
end
