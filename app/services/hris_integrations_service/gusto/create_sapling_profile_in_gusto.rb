class HrisIntegrationsService::Gusto::CreateSaplingProfileInGusto
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, :update_user_home_address, :get_gusto_company_location, :get_gusto_company, :update_user_compensation, to: :helper_service
  delegate :create_user, :create_user_job, to: :endpoint_service, prefix: :execute 

  def initialize(company, user, integration, data_builder, params_builder)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
  end

  def perform
    create
  end

  private

  def create
    request_data = @data_builder.build_create_profile_data(@user)
    request_params = @params_builder.build_create_profile_params(request_data)
    return unless request_params.present?

    begin
      response = execute_create_user(@integration, request_params["user"], @integration.company_code) 
      parsed_response = JSON.parse(response.read_body)
      if response.code == '201'
        
        employee_id = parsed_response['id']
        user.update_column(:gusto_id, employee_id)
        loggings('Success', response.code, parsed_response, "Create user in gusto", request_data, request_params["user"])  
        
        update_user_home_address(@company, @integration, employee_id, request_data, request_params["home_address"])
        compensations_ids = create_user_job(employee_id, request_data, request_params["jobs"], @integration.company_code)
        update_user_compensation(@company, @integration, request_data, request_params["compensations"], compensations_ids[:id], compensations_ids[:version]) if compensations_ids.present?
      else
        loggings('Failure', response.code, parsed_response, "Create user in gusto",  request_data, request_params["users"])
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, "Create user in gusto", request_data, request_params)
    end
  end

  private 

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end

  def endpoint_service
    HrisIntegrationsService::Gusto::Endpoint.new
  end

  def loggings status, code, parsed_response, action, request_data, request_params
    create_loggings(@company, 'Gusto', code, "#{action} - #{status}", {response: parsed_response}, {data: request_data, params: request_params})
    log_statistics(status.downcase, @company)
  end

  def create_user_job(employee_id, request_data, request_params, company_code)
    response = get_gusto_company_location(@company, @integration, @user.location_name, company_code)
    if response[:code] == 200 && response[:location_id].present?
      request_params[:location_id] = response[:location_id]
      response = execute_create_user_job(@integration, employee_id, request_params) 
      parsed_response = JSON.parse(response.read_body)

      if response.code == '201'
        loggings('Success', response.code, parsed_response, "Create user jobs in gusto", request_data, request_params)  
        return {id: parsed_response['compensations'][0]["id"], version: parsed_response['compensations'][0]["version"]}
      else
        loggings('Failure', response.code, parsed_response, "Create user jobs in gusto", request_data, request_params)
        return
      end
    else
      loggings('Failure', response[:code], response[:parsed_response], "Company does not exist in Gusto", request_data, request_params)
      return
    end

  end
end