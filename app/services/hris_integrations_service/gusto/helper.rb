class HrisIntegrationsService::Gusto::Helper
  delegate :update_user_home_address, :get_gusto_company, :get_gusto_company_location, :update_user_compensation, to: :endpoint_service, prefix: :execute
  
  def fetch_integration(company, user, instance_id=nil)
    if user.present? && instance_id.blank?
      company.integration_instances.where(api_identifier: 'gusto').find_each do |instance|
        return instance if can_integrate_profile?(instance, user)
      end
    else
      company.integration_instances.find_by(id: instance_id)  
    end
  end
 
  def is_integration_valid?(integration)
    integration.present? && integration.company_code.present? && integration.access_token.present? && integration.refresh_token.present? && integration.expires_in.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def create_loggings(company, integration_name, state, action, result = {}, api_request = 'No Request')
    LoggingService::IntegrationLogging.new.create(
      company,
      integration_name,
      action,
      api_request,
      result,
      state.to_s
    )
  end

  def apply_to_location?(filter, user)
    location_ids = filter['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filter, user)
    team_ids = filter['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filter, user)
    employee_types = filter['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type.present? && employee_types.include?(user.employee_type_field_option&.option))
  end
  
  def log_statistics(action, company)
    if action == 'success'
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end

  def vendor_domain
    Rails.env.production? ? 'api.gusto.com' : 'api.gusto-demo.com'
  end

  def update_user_home_address(company, integration, employee_id, request_data, request_params, version=nil)
    request_params[:version] = version if version.present?
    response = execute_update_user_home_address(integration, employee_id, request_params) 
    parsed_response = JSON.parse(response.body)
    if response.code == 200
      loggings(company, 'Success', response.code, parsed_response, "Update Home Address in Gusto",  request_data, request_params)  
      return response
    else
      loggings(company, 'Failure', response.code, parsed_response, "Update Home Address in Gusto", request_data, request_params)
      return response
    end
  end

  def loggings company, status, code, parsed_response, action, request_data=nil, request_params=nil
    create_loggings(company, 'Gusto', code, "#{action} - #{status}", {response: parsed_response}, {data: request_data, params: request_params})
    log_statistics(status.downcase, company)
  end

  def get_gusto_company_location(company, integration, user_location, company_code)
    user_location = user_location&.downcase
    response = execute_get_gusto_company_location(integration, company_code)
    parsed_response = JSON.parse(response.body)
    if response.code == 200
      parsed_response.each do |response_location|
        if location_matched?(response_location, user_location, company.subdomain)
          loggings(company, 'Success', response.code, parsed_response, "Get company location from gusto")
          return {code: response.code, location_id: response_location["id"]}
        end
      end
      return {code: 404, parsed_response: parsed_response}
    else
      return {code: response.code, parsed_response: parsed_response }
    end   
  end

  def get_gusto_company(company, integration, user_location)
    user_location = user_location&.downcase
    response = execute_get_gusto_company(integration)
    parsed_response = JSON.parse(response.body)
    if response.code == 200
      parsed_response.each do |response_company|
        response_company["locations"].each do |response_location|
          if user_location == response_location["city"].downcase || user_location == response_location["state"].downcase || user_location == "#{response_location["city"]}, #{response_location["state"]}".downcase
            loggings(company, 'Success', 200, parsed_response, "Get company from gusto")
            return response_company["id"]
          end
        end
      end
      return
    else
      return
    end   
  end

  def update_user_compensation(company, integration, request_data, request_params, compensation_id, version)
    request_params[:version] = version if version.present?
    response = execute_update_user_compensation(integration, compensation_id, request_params) 
    parsed_response = JSON.parse(response.body)
    if response.code == 200
      loggings(company, 'Success', response.code, parsed_response, "Update User Compensation in Gusto",  request_data, request_params)  
      return response
    else
      loggings(company, 'Failure', response.code, parsed_response, "Update User Compensation in Gusto", request_data, request_params)
      return response
    end
  end

  def endpoint_service
    HrisIntegrationsService::Gusto::Endpoint.new
  end

  def verify_state_and_fetch_company(payload)
    begin 
      ids = JsonWebToken.decode(payload[:state])
      company = Company.find_by(id: ids["company_id"].to_i)
      instance = company.integration_instances.find_by(id: ids["instance_id"].to_i)
      user_id = ids["user_id"].to_i
      if instance.present?
        return company, instance.id, user_id
      else
        raise CanCan::AccessDenied
      end
    rescue Exception => e
      raise CanCan::AccessDenied
    end
  end

  def fetch_and_save_companies(integration, company)
    begin
      response = execute_get_gusto_company(integration)
      parsed_response = JSON.parse(response.body)
      if response.code == 200
        configuration = integration.integration_inventory.integration_configurations.find_by(field_name: 'Company Code')
        
        return 'failed' unless configuration.present?
        
        company_code = integration.integration_credentials.find_or_create_by(name: configuration.field_name, integration_configuration_id: configuration.id)

        data = []
        parsed_response.each do |response_company|
          data.push({label: response_company['name'], value: response_company['id']})
        end      
        company_code.update(dropdown_options: data)
        loggings(company, 'Success', 200, parsed_response, "Get company from gusto")
        return 'success'
      else
        loggings(company, 'Failure', response.code, parsed_response, "Get company from gusto")
        return 'failed'
      end   
    rescue Exception => e
      loggings(company, 'Failure', 500, e.message, "Get company from gusto")
      return 'failed'
    end
  end

  private

  def location_matched?(response_loc, user_loc, company_subdomain)
    city, state = response_loc['city'].downcase, response_loc['state'].downcase
    oura_location_check = ((company_subdomain == 'oura') && response_loc['id'] == 7757869461060827)
    staging_location_check = (Rails.env.staging? && response_loc['id'] == 7757727716282571)
    (oura_location_check || staging_location_check) || (response_loc['active'] && [city, state, "#{city}, #{state}"].include?(user_loc))
  end

end
