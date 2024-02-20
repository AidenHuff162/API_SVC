CarrierWave.configure do |config|
  if !Rails.env.development? && !Rails.env.test?
    config.aws_credentials = {
      region:            ENV['AWS_REGION'],
      access_key_id:     ENV['AWS_ACCESS_KEY'],
      secret_access_key: ENV['AWS_SECRET_KEY']
    }
    config.storage       = :aws
    config.aws_acl       = 'private'
    config.aws_bucket    = ENV['AWS_BUCKET']
    config.store_dir     = nil # store at the root level
    config.aws_authenticated_url_expiration = 60 * 60 * 24 * 7

  elsif  Rails.env.development?
    config.storage = :file
  elsif Rails.env.test?
    config.storage = :file
    config.enable_processing = false
  end
end
