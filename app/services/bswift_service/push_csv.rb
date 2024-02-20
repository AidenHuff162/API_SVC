class BswiftService::PushCsv

  def initialize(filename, integration, company)
    @filename = filename
    @integration = integration
    @company = company
  end

  def perform
    uploading_states = ""
    remote_path = @integration.bswift_remote_path + "/" + @filename.split("/")[-1]
    begin
      Net::SFTP.start(@integration.bswift_hostname, @integration.bswift_username, password: @integration.bswift_password, port: 22) do |sftp|
        sftp.upload!(@filename, remote_path) do |event, uploader, *args|
          case event
          when :open then
            uploading_states += "open: starting upload: #{args[0].local} -> #{args[0].remote} (#{args[0].size} bytes} \n"
          when :put then
            uploading_states += "put: writing #{args[2].length} bytes to #{args[0].remote} starting at #{args[1]} \n"
          when :close then
            uploading_states += "close: finished with #{args[0].remote} \n"
          when :finish then
            uploading_states += "finish: all done! \n"
          end
        end
        sftp.channel.eof!
      end
      logging.create(@company, 'BSwift', "Push CSV to SFTP Endpoint - Success", nil, { :filename => remote_path }.to_json, 200)
      return 1
    rescue Exception => e
      logging.create(@company, 'BSwift', "Push CSV to SFTP Endpoint - Failure", nil, { :error => e.to_s, uploading_states: uploading_states }.to_json, 500)
      return -1
    end
  end

  private
  def logging
    LoggingService::IntegrationLogging.new
  end

end
