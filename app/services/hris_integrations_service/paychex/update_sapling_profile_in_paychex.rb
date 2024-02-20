class HrisIntegrationsService::Paychex::UpdateSaplingProfileInPaychex
	attr_reader :company, :user, :integration, :data_builder, :params_builder, :updated_attributes

  delegate :create_loggings, :notify_slack, :log_statistics, to: :helper_service
  delegate :update, to: :endpoint_service, prefix: :execute

  def initialize(company, user, integration, data_builder, params_builder, updated_attributes)
    @company = company
    @user = user
    @integration = integration
    @data_builder = data_builder
    @params_builder = params_builder
    @updated_attributes = updated_attributes
  end

  def perform
    update
  end

  private
  
  def update
    request_data = @data_builder.build_update_profile_data(@user, @updated_attributes)
    request_params = @params_builder.build_update_profile_params(request_data)
    return unless request_params.present?
    
    begin
      response = execute_update(@integration, @user.paychex_id, request_params)
      parsed_response = JSON.parse(response.body)
      
      if response.ok?
        create_loggings(@company, 'Paychex', response.code, "Update user in Paychex - Success", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('success', @company)
      else
        create_loggings(@company, 'Paychex', response.code, "Update user in Paychex - Failure", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('success', @company)
      end
    rescue Exception => e
      create_loggings(@company, 'Paychex', 500, "Update user in Paychex - Failure", {response: e.message}, {data: request_data, params: request_params}.inspect)
      log_statistics('failed', @company)
    end
  end

  def helper_service
    HrisIntegrationsService::Paychex::Helper.new
  end

  def endpoint_service
    HrisIntegrationsService::Paychex::Endpoint.new
  end
end	
