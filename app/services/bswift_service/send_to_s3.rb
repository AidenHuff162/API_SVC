class BswiftService::SendToS3

  def initialize(filename, company)
    @filename = filename
    @company = company
  end

  def perform
    begin
      key = "bswift_csv/#{Date.today.to_s}/#{@filename}.zip"
      object = Aws::S3::Resource.new(access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'], region: ENV['AWS_REGION']).bucket(ENV['AWS_BUCKET']).object(key)
      object.upload_file(@filename, acl: 'private')

      logging.create(@company, 'BSwift', "Upload CSV to S3 - Success", nil, {}, 200)
      return 1
    rescue Exception => e
      logging.create(@company, 'BSwift', "Upload CSV to S3 - Failure", nil, {message: e.message}, 500)
      return -1
    end
  end

  private
  private
  def logging
    LoggingService::IntegrationLogging.new
  end
end
