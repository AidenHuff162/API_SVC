class HrisIntegrationsService::Gusto::AuthenticateApplication
  require 'openssl'
  
  attr_reader :company, :integration, :user_id

  delegate :create_loggings, :fetch_integration, :vendor_domain, :log_statistics, :fetch_and_save_companies, to: :helper_service

  def initialize(company, instance_id, user_id=nil)
    @company = company
    @integration = fetch_integration(company, nil, instance_id) 
    @user_id = user_id
  end

  def authentication_request_url
    return 'failed' unless @integration.present?
    prepare_authetication_url
  end

  def authorize(authcode)
    return 'failed' unless authcode.present? && @integration.present?
    authorisation_data = exchange_authcode_to_access_token(authcode)

    return 'failed' unless authorisation_data.present?
    save_authentication_credentials(authorisation_data)
    fetch_and_save_companies(@integration, @company)
  end

  def reauthorize
    return 'failed' unless @integration.present?
    
    authorisation_data = refresh_access_token
    return 'failed' unless authorisation_data.present?
    
    save_authentication_credentials(authorisation_data)
  end

  private

  def redirect_uri
    if Rails.env.development?
      "https://rocketship.ngrok.io/gusto-callback"
    elsif (Rails.env.staging?) || (Rails.env.production? && ENV['DEFAULT_HOST'] == 'saplinghr.com')
      "https://#{@company.domain}/gusto-callback"
    else
      "https://www.saplingapp.io/gusto-callback"
    end
  end

  def prepare_authetication_url
    state = JsonWebToken.encode({company_id: @company.id, instance_id: integration.id, user_id: user_id})
    { url: "https://#{vendor_domain}/oauth/authorize?client_id=#{ENV['GUSTO_CLIENT_ID']}&redirect_uri=#{CGI.escape(redirect_uri)}&response_type=code&state=#{state}" }
  end

  def generate_access_token(content)
    Net::HTTP.post_form(URI("https://#{vendor_domain}/oauth/token"), content)
  end

  def regenerate_access_token(content)
    Net::HTTP.post_form(URI("https://#{vendor_domain}/oauth/token"), content)
  end

  def exchange_authcode_to_access_token(authcode)
    content = {
      grant_type: 'authorization_code',
      client_id: ENV['GUSTO_CLIENT_ID'],
      client_secret: ENV['GUSTO_CLIENT_SECRET'],
      redirect_uri: redirect_uri,
      code: authcode
    }
    
    begin
      response = generate_access_token(content)
      if response.message == 'OK'
        parsed_response = JSON.parse(response.body)
        loggings(response.code, 'Generate access token - Success', response, content, 'Success')
        
        return parsed_response
      else
        loggings(response.code, 'Generate access token - Failed', response, content, 'Failed')
      end 
    rescue Exception => e
      loggings(500, 'Generate access token - Failed', e.message, content, 'Failed')
    end

    return
  end

  def refresh_access_token

    content = {
      grant_type: 'refresh_token',
      client_id: ENV['GUSTO_CLIENT_ID'],
      client_secret: ENV['GUSTO_CLIENT_SECRET'],
      redirect_uri: redirect_uri,
      refresh_token: integration.refresh_token
    }

    begin
      response = regenerate_access_token(content)
      if response.message == 'OK'
        parsed_response = JSON.parse(response.body)
        loggings(response.code, 'Regenerate access token - Success', response, content, 'Success')

        return parsed_response
      else
        loggings(response.code, 'Regenerate access token - Failed', response, content, 'Failed')
      end 
    rescue Exception => e
      loggings(500, 'Regenerate access token - Failed', e.message, content, 'Failed')
    end

    return
  end

  def save_authentication_credentials(authorisation_data)
    integration.access_token(authorisation_data['access_token'])
    integration.refresh_token(authorisation_data['refresh_token'])
    integration.expires_in(Time.now.utc + authorisation_data['expires_in'])
    integration.attributes = {is_authorized: true, connected_at: Time.now}
    integration.connected_by_id = user_id if user_id.present?

    integration.save!
    return 'success'
  end

  def loggings(code, action, result, request = nil, status)
    create_loggings(@company, 'Gusto', code, action, {result: result}, request)
    log_statistics(status.downcase, @company)  
  end

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end
end