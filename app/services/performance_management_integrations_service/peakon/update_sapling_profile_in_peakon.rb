class PerformanceManagementIntegrationsService::Peakon::UpdateSaplingProfileInPeakon
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :update, to: :endpoint_service, prefix: :execute 

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
    update_by_scim
  end

  def update_by_scim
    request_data = @data_builder.build_update_profile_data(@user, @attributes, 'scim')
    request_params = @params_builder.build_update_profile_params(request_data)

    return unless request_params.present?
    
    begin
      response = execute_update(@integration, request_params, user)
      if response.ok?
        loggings('Success', response.code, response, request_data, request_params)
      else
        loggings('Failure', response.code, response, request_data, request_params)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, request_data, request_params)
    end
  end

  def endpoint_service
    PerformanceManagementIntegrationsService::Peakon::Endpoint.new
  end

  def helper_service
    PerformanceManagementIntegrationsService::Peakon::Helper.new
  end

  def loggings status, code, response, request_data, request_params
    create_loggings(@company, 'Peakon', code, "Update user in peakon - #{status}", {response: response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end