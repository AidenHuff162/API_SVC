class SsoIntegrationsService::Gsuite::AuthenticateApplication
  require 'openssl'
  
  attr_reader :company, :request_host

  APPLICATION_NAME = 'Sapling Gsuite'

  def initialize(company, request_host)
    @company = company
    @request_host = request_host
  end

  def prepare_authentication_url
    { url: get_gsuite_auth_credential}
  end

  def get_gsuite_auth_credential
    service = Google::Apis::AdminDirectoryV1::DirectoryService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize
  end

  def authorize
    get_authorizer(@company)
    credentials = @authorizer.get_credentials_from_relation(@company, @company.id)
    if credentials.nil?  
      url = @authorizer.get_authorization_url(base_url: set_base_url,state: @company.id)
      url
    else
      if Rails.env == "development"
         "http://#{@company.app_domain}/#/admin/settings/integrations?goauthres=Account already authorized"
      else
         "https://" + @company.app_domain + "/#/admin/settings/integrations?goauthres=Account already authorized"
      end
    end
  end

  def get_authorizer(company)
    if company.present?
      auth_lib_obj = Gsuite::GoogleApiAuthorizer.new
      @authorizer = auth_lib_obj.get_authorizer(company)
    end
  end

  def set_base_url
    @base_url = @request_host.include?("saplingapp.io") ? "https://www.saplingapp.io/api/v1/oauth2callback" : "https://#{request_host}/api/v1/oauth2callback"
  end  
end