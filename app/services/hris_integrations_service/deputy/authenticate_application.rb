class HrisIntegrationsService::Deputy::AuthenticateApplication
  require 'openssl'
  
  attr_reader :company, :integration

  delegate :create_loggings, :fetch_integration, to: :helper_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def authentication_request_url
    prepare_authetication_url
  end

  def authorize(authcode)
    return 'failed' unless authcode.present?
      
    authorisation_data = exchange_authcode_to_access_token(authcode)
    return 'failed' unless authorisation_data.present?

    save_authentication_credentials(authorisation_data)
  end

  def reauthorize
    authorisation_data = refresh_access_token
    return 'failed' unless authorisation_data.present?
    
    save_authentication_credentials(authorisation_data)
  end

  private

  def redirect_uri
    if Rails.env.development?
      "https://rocketship.ngrok.io/api/v1/deputy_authorize"
    else
      "https://#{@company.domain}/api/v1/deputy_authorize"
    end
  end

  def prepare_authetication_url
    { url: "https://once.deputy.com/my/oauth/login?client_id=#{integration.client_id}&redirect_uri=#{redirect_uri}&response_type=code&scope=longlife_refresh_token" }
  end

  def generate_access_token(content)
    Net::HTTP.post_form(URI('https://once.deputy.com/my/oauth/access_token'), content)
  end

  def regenerate_access_token(content, subdomain)
    Net::HTTP.post_form(URI("https://#{subdomain}/oauth/access_token"), content)
  end

  def exchange_authcode_to_access_token(authcode)
    content = {
      grant_type: 'authorization_code',
      scope: 'longlife_refresh_token',
      client_id: integration.client_id,
      client_secret: integration.client_secret,
      redirect_uri: redirect_uri,
      code: authcode
    }
    
    begin
      response = generate_access_token(content)
      if response.message == 'OK'
        parsed_response = JSON.parse(response.body)
        log(response.code, 'Generate access token - Success', response, content)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)

        return parsed_response
      else
        log(response.code, 'Generate access token - Failed', response, content)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end 
    rescue Exception => e
      log(500, 'Generate access token - Failed', e.message, content)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end

    return
  end

  def refresh_access_token
    content = {
      grant_type: 'refresh_token',
      scope: 'longlife_refresh_token',
      client_id: integration.client_id,
      client_secret: integration.client_secret,
      redirect_uri: redirect_uri,
      refresh_token: integration.refresh_token
    }

    begin
      response = regenerate_access_token(content, integration.subdomain)
      if response.message == 'OK'
        parsed_response = JSON.parse(response.body)
        log(response.code, 'Regenerate access token - Success', response, content)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)

        return parsed_response
      else
        log(response.code, 'Regenerate access token - Failed', response, content)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end 
    rescue Exception => e
      log(500, 'Regenerate access token - Failed', e.message, content)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end

    return
  end

  def save_authentication_credentials(authorisation_data)
    return 'failed' if authorisation_data['access_token'].blank? || authorisation_data['refresh_token'].blank? || authorisation_data['endpoint'].gsub("https://", "").blank? || authorisation_data['expires_in'].blank?

    integration.access_token(authorisation_data['access_token']) 
    integration.refresh_token(authorisation_data['refresh_token'])
    integration.subdomain(authorisation_data['endpoint'].gsub("https://", ""))
    integration.expires_in(Time.now.utc + authorisation_data['expires_in'])
    integration.update_column(:is_authorized, true)
    
    manage_deputy_company 
    return 'success'
  end

  def manage_deputy_company
    ::HrisIntegrationsService::Deputy::ManageDeputyCompanies.new.create_deputy_company(integration)
    integration.update_column(:synced_at, DateTime.now)
    ::HrisIntegrations::Deputy::UpdateSaplingUserFromDeputyJob.perform_async(@company.id)
  end

  def log(status, action, result, request = nil)
    create_loggings(@company, 'Deputy', status, action, {result: result}, request)
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end