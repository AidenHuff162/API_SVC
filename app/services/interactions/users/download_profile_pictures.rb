module Interactions
  module Users
    class DownloadProfilePictures
      
      def initialize(company_id, admin_email)
        @company = Company.find_by(id: company_id)
        @admin_email = admin_email
        @secure_token = SecureRandom.urlsafe_base64(16)
      end

      def perform
        return unless @company.present? && @admin_email.present?

        send_downloadable_email
      end

      private

      def get_zip_filename
        "#{@company.name} Profile Pictures (#{Time.now.in_time_zone(@company.time_zone).strftime("%m-%d-%Y").to_s}) - #{@secure_token}.zip"
      end

      def get_zip_filepath(tmpdir)
        if Rails.env.development? || Rails.env.test?
          return "public/#{get_zip_filename}"
        else
          return "#{tmpdir}/#{get_zip_filename}"
        end
      end

      def get_filename(user)
        "#{user.full_name} - #{user.email.to_s || user.personal_email.to_s} (#{user.created_at.strftime('%d-%m-%Y')}).jpeg"
      end

      def get_profile_picture_download_url(user, filename)
        user.profile_image&.file&.download_url(filename)
      end

      def download_temp_file(download_url, tmpdir)
        File.open("#{tmpdir}/#{SecureRandom.urlsafe_base64}.jpeg", 'wb').tap do |file|
          if Rails.env.development? || Rails.env.test?
            file.write(File.read("public#{download_url}"))
          else
            profile_photo = HTTP.get(download_url)
            file.write(profile_photo.body)
          end
        end
      end

      def generate_zip_file(tmpdir)
        filepath = get_zip_filepath(tmpdir)

        Zip::File.open(filepath, Zip::File::CREATE) do |zip|
          @company.users.find_each do |user|
            if user.profile_image.present? && user.profile_image&.file&.url.present?
              begin
                filename = get_filename(user)
                download_url = get_profile_picture_download_url(user, filename)

                if download_url.present? && working_url?(URI.encode(download_url))
                  tempfile = download_temp_file(download_url, tmpdir)
                  zip.add(filename, tempfile.path)
                end
              rescue Exception => e
                puts e.inspect
              end
            end
          end
        end

        filepath
      end

      def upload_file_to_s3(downloadable_filepath)
        key = "pictures/#{Rails.env}/#{Date.today.to_s}/#{get_zip_filename}"

        object = Aws::S3::Resource.new(
          access_key_id: ENV['AWS_ACCESS_KEY'],
          secret_access_key: ENV['AWS_SECRET_KEY'],
          region: ENV['AWS_REGION']
        ).bucket(ENV['AWS_BUCKET']).object(key)

        object.upload_file(downloadable_filepath, acl: 'private')

        object
      end

      def send_downloadable_email
        Dir.mktmpdir do |tmpdir|
          filepath = generate_zip_file(tmpdir)

          if Rails.env.development? || Rails.env.test?
            url = "http://#{@company.subdomain}.#{Rails.env}:3000/#{filepath.split('public/')[1]}" if Rails.env.development?
            url = "http://#{@company.subdomain}.#{Rails.env}:3001/#{filepath.split('public/')[1]}" if Rails.env.test?
          else
            url = upload_file_to_s3(filepath).presigned_url(:get, expires_in: 8.hours.to_s.to_i)
          end

          UserMailer.download_all_profile_pictures_email(@company.id, url, @admin_email).deliver_now!
        end
      end

      def working_url?(url)
        return true if Rails.env.development? || Rails.env.test?
        
        uri = URI.parse(url)
        uri.is_a?(URI::HTTPS) && !uri.host.nil?
        rescue URI::InvalidURIError
        false
      end
    end
  end
end