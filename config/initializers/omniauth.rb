# config/initializers/omniauth.rb
Rails.application.config.middleware.use OmniAuth::Builder do
  OmniAuth.config.allowed_request_methods = [:post, :get]
  provider :google_oauth2, ENV['GOOGLE_OAUTH_API_KEY'], ENV['GOOGLE_OAUTH_SECRET_TOKEN'], strategy_class: OmniAuth::Strategies::GoogleOauth2
  provider :azure_oauth2, client_id: ENV['AZURE_AD_CLIENT_ID'], client_secret: ENV['AZURE_AD_CLIENT_SECRET'], strategy_class: OmniAuth::Strategies::AzureOauth2

end
