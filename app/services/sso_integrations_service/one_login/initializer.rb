require 'httparty'

class SsoIntegrationsService::OneLogin::Initializer
  attr_reader :company, :one_login_api

  def initialize(company)
    @company = company
    @one_login_api = initialize_one_login_api
  end

  def one_login_api_initialized?
    one_login_api.present? && one_login_api.client_id.present? && one_login_api.client_secret.present? && one_login_api.region.present?
  end

  def can_create_profile?
    one_login_api_initialized? && one_login_api.enable_create_profile.present?
  end

  def can_update_profile?
    one_login_api_initialized? && one_login_api.enable_update_profile.present?
  end

  def fetch_region
    one_login_api.region.downcase if one_login_api_initialized?
  end

  def fetch_access_token
    return unless one_login_api_initialized?

    token = retrieve_access_token
    generate_logs(token)

    return token['access_token'] if !token['status'].present?
  end

  def log(status, action, result, request = nil)
    LoggingService::IntegrationLogging.new.create(company, 'OneLogin', action, request, {result: result}, status)
  end

  private

  def initialize_one_login_api
    company.present? && company.authentication_type == "one_login" ? company.integration_instances.find_by(api_identifier: 'one_login', state: :active) : nil
  end

  def retrieve_access_token
    response = HTTParty.post("https://api.#{fetch_region}.onelogin.com/auth/oauth2/v2/token",
      basic_auth: { username: one_login_api.client_id, password: one_login_api.client_secret },
      body: { grant_type: 'client_credentials' }.to_json,
      headers: { 'content-type' => 'application/json' }
    )
    JSON.parse(response.body)
  end

  def generate_logs(response)
    LoggingService::IntegrationLogging.new.create(company, 'OneLogin', 'Retrieve Access Token - One Login', 'request connection', {result: response}, 200)
  end
end
