class SsoIntegrationsService::ActiveDirectory::AuthenticateApplication
  require 'openssl'
  
  attr_reader :company

  MICROSOFT_HOST = 'https://graph.microsoft.com'
  MICROSOFT_SCOPE = 'offline_access User.ReadWrite.All Directory.ReadWrite.All Directory.AccessAsUser.All Directory.AccessAsUser.All email openid profile AuditLog.Read.All'
  MICROSOFT_CALLBACK_PATH = '/hr/api/v1/active_directory_authorize'

  delegate :create_loggings, :fetch_integration, to: :helper_service
  delegate :log_success_hris_statistics, :log_failed_hris_statistics, to: :integration_statistic_management_service

  def initialize(company)
    @company = company
    @integration = fetch_integration(@company)
  end

  def authentication_request_url
    { url: prepare_authetication_url }
  end

  def authorize(response)
    authorisation_data = exchange_code_to_get_access_token(response)
    return 'failed' unless authorisation_data.present?

    save_authentication_credentials(authorisation_data)
  end

  def reauthorize
    authorisation_data = refresh_access_token
    return 'failed' unless authorisation_data.present?
    
    save_authentication_credentials(authorisation_data)
  end

  private

  def prepare_authetication_url
    return unless @integration.present?

    client = Signet::OAuth2::Client.new(
      authorization_uri: get_microsoft_authorization_uri,
      client_id: ENV['AZURE_AD_CLIENT_ID'],
      response_type: 'code',
      response_mode: 'query',
      scope: MICROSOFT_SCOPE,
      redirect_uri: REDIRECT_URL,
      admin_consent: true,
      state: state
    )
    client.authorization_uri.to_s
  end

  def generate_access_token(content)
    headers = { 'Content-Type': 'application/x-www-form-urlencoded' }
    HTTParty.post(URI(get_microsoft_token_uri), headers: headers, body: content)
  end

  def exchange_code_to_get_access_token(params)
    return unless @integration.present?

    content = {
      grant_type: 'authorization_code',
      code: params[:code],
      client_id: ENV['AZURE_AD_CLIENT_ID'],
      client_secret: ENV['AZURE_AD_CLIENT_SECRET'],
      scope: MICROSOFT_SCOPE,
      redirect_uri: REDIRECT_URL,
    }

    begin
      response = generate_access_token(content)

      if response.message == 'OK'
        parsed_response = response.parsed_response
        log('success', response.code, 'Generate access token - Success', response.inspect, content.inspect)
        
        return parsed_response
      else
        log('failed', response.code, 'Generate access token - Failed', response.inspect, content.inspect)
      end 
    rescue Exception => e
      log('failed', 500, 'Generate access token - Failed', e, content.inspect)
    end

    return
  end

  def refresh_access_token
    return unless @integration.present?

    content = {
      grant_type: 'refresh_token',
      client_id: ENV['AZURE_AD_CLIENT_ID'],
      client_secret: ENV['AZURE_AD_CLIENT_SECRET'],
      scope: MICROSOFT_SCOPE,
      refresh_token: @integration.refresh_token,
      redirect_uri: REDIRECT_URL,
    }

    begin
      response = generate_access_token(content)

      if response.message == 'OK'
        parsed_response = response.parsed_response
        log('success', response.code, 'Regenerate access token - Success', response.inspect, content.inspect)
        
        return parsed_response
      else
        log('failed', response.code, 'Regenerate access token - Failed', response.inspect, content.inspect)
      end 
    rescue Exception => e
      log('failed', 500, 'Regenerate access token - Failed', e, content.inspect)
    end

    return
  end

  def save_authentication_credentials(authorisation_data)
    @integration.access_token(authorisation_data['access_token'])
    @integration.refresh_token(authorisation_data['refresh_token'])
    @integration.expires_in(Time.now.utc + authorisation_data['expires_in'])

    return 'failed' if @integration.access_token.blank? || @integration.refresh_token.blank? || @integration.expires_in.blank?
    
    @integration.save!
    return 'success'
  end

  def log(state, status, action, result, request = nil)
    create_loggings(@company, 'Active Directory', status, action, {result: result}, request)

    if state == 'success'
      log_success_hris_statistics(@company)
    else
      log_failed_hris_statistics(@company)
    end
  end

  def helper_service
    ::SsoIntegrationsService::ActiveDirectory::Helper.new
  end

  def integration_statistic_management_service
    ::RoiManagementServices::IntegrationStatisticsManagement.new
  end

  def get_microsoft_authorization_uri
    "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?prompt=consent"
  end

  def get_microsoft_token_uri
    "https://login.microsoftonline.com/common/oauth2/v2.0/token"
  end

  def state
    JsonWebToken.encode({company_id: @company.id, instance_id: @integration&.id, subdomain: @company.subdomain})
  end
end