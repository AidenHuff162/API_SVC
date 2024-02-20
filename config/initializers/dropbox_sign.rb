require 'dropbox-sign'

Dropbox::Sign.configure do |config|
  config.username = ENV['HELLOSIGN_API_KEY']
end