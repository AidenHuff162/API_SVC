require 'dynamoid'

Dynamoid.configure do |config|
  config.namespace = nil

  config.access_key = ENV['AWS_ACCESS_KEY']
  config.secret_key = ENV['AWS_SECRET_KEY']
  config.region = ENV['AWS_REGION']
end