require 'net/sftp'
module SftpService
  class SendFileToSftp
    attr_reader  :sftp, :is_test, :host_uri, :file_path, :email_recipient, :report_name

    def initialize(sftp, file_path, is_test = false, name = nil, email_recipient = nil)
      @sftp = sftp
      @is_test = is_test
      @file_path = is_test ? generate_test_file.path : file_path
      @host_uri = URI.parse(sftp.host_url)
      @email_recipient = email_recipient
      @report_name = name
    end

    FILE_STORAGE_PATH = if Rails.env.development? || Rails.env.test?
                          ("#{Rails.root}/tmp")
                        else
                          File.join(Dir.home, 'www/sapling/shared/')
                        end
    def perform
      begin
        sftp.credentials? ? connect_by_credentials : connect_by_public_key
        send_sftp_upload_response_email(true) unless is_test
      rescue Exception => ex
        create_general_logging(ex.message)
        send_sftp_upload_response_email(false) unless is_test
        return false
      end

      return true
    end

    private

    def generate_test_file
      file = File.join(FILE_STORAGE_PATH, '/sftp.txt' )
      @out_file = File.new(file, 'w')
      @out_file.puts('SFTP export from Sapling successful - Hello World')
      @out_file.close
      @out_file
    end

    def connect_by_credentials
      Net::SFTP.start(host_uri.host, sftp.user_name , password: sftp.password, port: sftp.port) do |sftp_session|
        sftp_session.upload!(file_path, sftp.folder_path) do |event, uploader, *args|
          file_path
        end
        sftp_session.channel.eof!
      end
    end

    def connect_by_public_key
      public_key_file = get_public_key()
      Net::SFTP.start(host_uri.host, sftp.user_name, keys: public_key_file.path, keys_only: true, port: sftp.port) do |sftp_session|
        sftp_session.upload!(file_path, sftp.folder_path) do |event, uploader, *args|
          file_path
        end
        sftp_session.channel.eof!
      end
      public_key_file.close
    end

    def create_general_logging(data)
      LoggingService::GeneralLogging.new.create(sftp.company, 'SFTP - File Transfer Error', { sftp_id: sftp.id, sftp_name: sftp.name, error: data })
    end

    def send_sftp_upload_response_email(status)
      UserMailer.sftp_upload_response_email(email_recipient, status, report_name).deliver_now! 
    end

    def get_public_key
      return unless sftp.public_key?

      file_url = sftp.public_key.file.url
      file_extension = File.extname(sftp.public_key.original_filename)
      generate_temp_file(HTTParty.get(file_url).body, file_extension)
    end

    def generate_temp_file(data, file_extension)
      tempfile = Tempfile.new(['doc', file_extension])
      tempfile.binmode.write(data)
      tempfile.rewind
      tempfile
    end
  end
end
