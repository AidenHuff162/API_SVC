class AtsIntegrationsService::HireBridge
  attr_reader :current_company, :hire_bridge_integration, :payload

  def initialize(current_company, payload) 
    @current_company = current_company
    @payload = JSON.parse(payload[:_json])[0].try(:with_indifferent_access) 
    @hire_bridge_integration = fetch_integration(@current_company)
  end

  def create(access_token)
    if check_integration_credentials?(@current_company, @hire_bridge_integration) && check_authentication?(access_token)
      begin
        create_pending_hire

        create_webhook_logging('Hire Bridge', 'create', { payload: @payload, access_token: access_token }, 'succeed', 'AtsIntegrationsService::HireBridge/create' )
        return { message: 'Created', status: 201 }
      rescue Exception => e
        create_webhook_logging('Hire Bridge', 'create', { payload: @payload, access_token: access_token}, 'failed', 'AtsIntegrationsService::HireBridge/create', {error: e.message})
        return { message: 'Error', error: e.message, status: 500 }
      end
    else
      create_webhook_logging('Hire Bridge', 'authentication - create', { payload: @payload, access_token: access_token }, 'failed', 'AtsIntegrationsService::HireBridge/create' )
      raise CanCan::AccessDenied
    end
  end

  private

  def fetch_integration(company)
    company.integration_instances.find_by(api_identifier: "hire_bridge")
  end

  def check_integration_credentials?(company, integration = nil)
    integration = fetch_integration(company) if integration.blank?
    return integration.present? && integration.api_key.present? && integration.company_id == company.id
  end

  def check_integration_validity?(integration, api_token)
    return @hire_bridge_integration.present? && integration.present? && @hire_bridge_integration.id == integration.id && 
      @hire_bridge_integration.company_id == integration.company_id && @hire_bridge_integration.api_key.present? && 
      integration.api_key.present? && @hire_bridge_integration.api_key == integration.api_key && 
      @hire_bridge_integration.api_key == api_token && integration.api_key == api_token
  end

  def check_authentication?(api_token)
    access_token = JsonWebToken.decode(api_token)
    return false unless access_token.class == ActiveSupport::HashWithIndifferentAccess && 'hire_bridge' == access_token['source']
      
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
      title: @payload[:job_title],
      personal_email: @payload[:personal_email],
      start_date: @payload[:startdate]&.to_date,
      base_salary: @payload[:basesalary]
    }
    
    attributes[:location_id] = fetch_location_id(@payload[:location])
    attributes[:team_id] = fetch_team_id(@payload[:department])

    @current_company.pending_hires.create!(attributes)
  end

  def create_webhook_logging(integration, action, data, status, location, error=nil)
    @webhook_logging ||= LoggingService::WebhookLogging.new
    @webhook_logging.create(@current_company, integration, action, data, status, location, error)
  end
end