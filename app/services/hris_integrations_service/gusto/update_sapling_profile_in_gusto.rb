class HrisIntegrationsService::Gusto::UpdateSaplingProfileInGusto
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, :update_user_home_address, :update_user_compensation, to: :helper_service
  delegate :update_user, :get_gusto_employee, :update_user_job, to: :endpoint_service, prefix: :execute 

  def initialize(company, user, integration, data_builder, params_builder, attributes)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
    @attributes = attributes
  end

  def perform
    update
  end

  private
  
  def update
    request_data = @data_builder.build_update_profile_data(@user, @attributes)
    request_params = @params_builder.build_update_profile_params(request_data)
    gusto_ids = manage_gusto_version
    return unless request_params.present? && gusto_ids

    begin
      response = update_user(request_params["user"], request_data, gusto_ids[:version][:user]) if request_params["user"].present?
      response = update_user_home_address(@company, @integration, @user.gusto_id, request_data, request_params["home_address"], gusto_ids[:version][:home_address]) if (response.present? && response.ok? && request_params["home_address"].present?) || (request_params["user"].blank? && response.blank? && request_params["home_address"].present?)
      response = update_user_job(request_params["jobs"], request_data, gusto_ids[:version][:jobs], gusto_ids[:job_id]) if (response.present? && response.ok? && request_params["jobs"].present?) || (response.blank? && request_params["jobs"].present?)
      update_user_compensation(@company, @integration, request_data, request_params["compensations"], gusto_ids[:compensation_id], gusto_ids[:version][:compensation]) if (response.present? && response.ok? && request_params["compensations"].present?) || (response.blank? && request_params["compensations"].present?)
    rescue Exception => e
      loggings('Failure', 500, e.message, "Update user in gusto", request_data, request_params)
    end
  end

  def endpoint_service
    HrisIntegrationsService::Gusto::Endpoint.new
  end

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end

  def loggings status, code, response, action, request_data, request_params
    create_loggings(@company, 'Gusto', code, "#{action} - #{status}", {response: response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end

  def update_user(request_params, request_data, gusto_version) 
    request_params[:version] = gusto_version
    response = execute_update_user(@integration, request_params, @user.gusto_id) 
    parsed_response = JSON.parse(response.body)
    
    if response.ok?
      loggings('Success', response.code, parsed_response, "Update user in gusto", request_data, request_params)
      return response  
    else
      loggings('Failure', response.code, parsed_response, "Update user in gusto", request_data, request_params)
      return response
    end
  end

  def update_user_job(request_params, request_data, gusto_version, job_id)
    request_params[:version] = gusto_version
    response = execute_update_user_job(@integration, job_id, request_params)
    parsed_response = JSON.parse(response.body) 
    
    if response.ok?
      loggings('Success', response.code, parsed_response, "Update user job in gusto", request_data, request_params)  
      return response
    else
      loggings('Failure', response.code, parsed_response, "Update user job in gusto", request_data, request_params)
      return response
    end
  end

  def manage_gusto_version
    response = execute_get_gusto_employee(@integration, @user.gusto_id)
    parsed_response = JSON.parse(response.body)

    if response.code == 200
      version = {}
      version[:user] = parsed_response["version"]
      version[:home_address] = parsed_response["home_address"]["version"] rescue nil
      version[:jobs] =  parsed_response["jobs"][0]["version"] rescue nil
      version[:compensation] = parsed_response["jobs"][0]["compensations"][0]["version"] rescue nil
      job_id = parsed_response["jobs"][0]["id"] rescue nil
      compensation_id = parsed_response["jobs"][0]["current_compensation_id"] rescue nil
      data = {version: version, job_id: job_id, compensation_id: compensation_id}
      return data
    else 
      return nil
    end
  end
end