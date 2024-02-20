class AtsIntegrationsService::CustomAts
  attr_reader :current_company, :custom_ats_integration, :payload
  
  
  def initialize(current_company, payload) 
    @current_company = current_company
    @payload = payload
    @custom_ats_integration = fetch_integration(@current_company)
  end

  def authenticate(access_token)
    if check_integration_credentials?(@current_company, @custom_ats_integration) && check_authentication?(access_token)
      
      create_webhook_logging("Custom ATS - #{@payload[:source]}", 'Authenticate', { payload: @payload, access_token: access_token }, 'succeed', 'Service::AtsIntegrationsService::CustomAts/authenticate')
      return { message: 'Authenticated', status: 200 }
    else
      create_webhook_logging("Custom ATS - #{@payload[:source]}", 'Authenticate', { payload: @payload, access_token: access_token }, 'failed', 'Service::AtsIntegrationsService::CustomAts/authenticate')
      raise CanCan::AccessDenied
    end
  end

  def create(access_token)
    if check_integration_credentials?(@current_company, @custom_ats_integration) && check_authentication?(access_token)
      begin
        create_pending_hire

        create_webhook_logging("Custom ATS - #{@payload[:source]}", 'Create', { payload: @payload, access_token: access_token }, 'succeed', 'Service::AtsIntegrationsService::CustomAts/create')
        return { message: 'Created', status: 201 }
      rescue Exception => e
        create_webhook_logging("Custom ATS - #{@payload[:source]}", 'Create', { payload: @payload, access_token: access_token}, 'failed', 'Service::AtsIntegrationsService::CustomAts/create', e.message)
        return { message: 'Error', error: e.message, status: 500 }
      end
    else
      create_webhook_logging("Custom ATS - #{@payload[:source]}", "Authentication - Create", { payload: @payload, access_token: access_token }, 'failed', 'Service::AtsIntegrationsService::CustomAts/create')
      raise CanCan::AccessDenied
    end
  end

  private

  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: @payload[:source])
  end

  def check_integration_credentials?(company, integration = nil)
    integration = fetch_integration(company) if integration.blank?
    return integration.present? && integration.api_key.present? && integration.company_id == company.id && integration.api_identifier == @payload[:source]
  end

  def check_integration_validity?(integration, api_token)
    return @custom_ats_integration.present? && integration.present? && @custom_ats_integration.id == integration.id && 
      @custom_ats_integration.company_id == integration.company_id && @custom_ats_integration.api_key.present? && 
      integration.api_key.present? && @custom_ats_integration.api_key == integration.api_key && 
      @custom_ats_integration.api_key == api_token && integration.api_key == api_token &&
      @custom_ats_integration.api_identifier == @payload[:source] && integration.api_identifier == @payload[:source]
  end

  def check_authentication?(api_token)
    access_token = JsonWebToken.decode(api_token)
    return false unless access_token.class == ActiveSupport::HashWithIndifferentAccess && @payload[:source] == access_token['source']
      
    company ||= Company.find_by(id: access_token['company_id'], subdomain: access_token['subdomain'], account_state: 'active')
    return false unless company.present?

    integration = fetch_integration(company)
    return true if @current_company.id == company.id && check_integration_credentials?(company, integration) && check_integration_validity?(integration, api_token)
  end

  def fetch_location_id(location)
    return unless location.present?
    @current_company.locations.where('name ILIKE ?', location).take&.id
  end

  def fetch_team_id(team)
    return unless team.present?
    @current_company.teams.where('name ILIKE ?', team).take&.id
  end

  def fetch_manager_id(manager_email)
    return unless manager_email.present?
    @current_company.users.where('email ILIKE ? OR personal_email ILIKE ?', manager_email, manager_email).take&.id
  end

  def create_pending_hire
    attributes = {
      first_name: @payload[:first_name],
      last_name: @payload[:last_name],
      preferred_name: @payload[:preferred_name],
      title: @payload[:title],
      personal_email: @payload[:personal_email],
      state: (@payload[:state] || 'active'),
      employee_type: @payload[:employee_type],
      start_date: @payload[:start_date]&.to_date
    }
    
    attributes[:location_id] = fetch_location_id(@payload[:location])
    attributes[:team_id] = fetch_team_id(@payload[:department])
    attributes[:manager_id] = fetch_manager_id(@payload[:manager_email]) rescue nil

    @current_company.pending_hires.create!(attributes)
  end
  
  def create_webhook_logging integration, action, data, status, location, error=nil
    @webhook_logging ||= LoggingService::WebhookLogging.new
    @webhook_logging.create(@current_company, integration, action, data, status, location, error)
  end
end