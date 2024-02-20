class TeamSpiritService::SendToS3
  delegate :logging, to: :helper_service

  def initialize(filename, company)
     @filename = filename
     @company = company
  end

  attr_reader :company, :filename

  def perform
    key = "team_spirit_csvs/#{company.id}/#{filename}"
    begin      
      object = Aws::S3::Resource.new(access_key_id: ENV['AWS_ACCESS_KEY'], secret_access_key: ENV['AWS_SECRET_KEY'], region: ENV['AWS_REGION']).bucket(ENV['AWS_BUCKET']).object(key)
      object.upload_file( filename, acl: 'private')
      logging.create( company, 'TeamSpirit', "Upload CSV file: #{filename} to S3 - Success", nil, {}, 200)
      1
    rescue Exception => e
      logging.create( company, 'TeamSpirit', "Upload CSV file: #{filename} to S3 - Failure", nil, {message: e.message}, 500)
      -1
    end
  end

  def helper_service
    TeamSpiritService::Helper.new
  end
end
