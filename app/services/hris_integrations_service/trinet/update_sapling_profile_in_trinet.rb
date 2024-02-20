class HrisIntegrationsService::Trinet::UpdateSaplingProfileInTrinet
	attr_reader :company, :user, :integration, :data_builder, :params_builder, :updated_attribute, :section

  delegate :create_loggings, :notify_slack, :log_statistics, to: :helper_service
  delegate :update, to: :endpoint_service, prefix: :execute

  def initialize(company, user, integration, data_builder, params_builder, updated_attribute, section)
    @company = company
    @user = user
    @integration = integration
    @data_builder = data_builder
    @params_builder = params_builder
    @updated_attribute = updated_attribute
    @section = section
  end

  def perform
    update
  end

  private

  def get_request_params(attributes)
    request_data = @data_builder.build_update_profile_data(@user, attributes)
    request_params = @params_builder.build_update_profile_params(request_data)
  end
  
  def update
    return unless updated_attribute.present? || section.present?
    begin
      request_params = get_request_params(updated_attribute)
      return unless request_params.present?

      case section
      when 'job_reclassification'
        url = "v1/manage-employee/#{integration.company_code}/#{user.trinet_id}/jobs"
        @response =  execute_update(integration, url, request_params["job_reclassification"])
      when 'personal'
        url = "v1/identity/#{integration.company_code}/#{user.trinet_id}/personals"
        @response =  execute_update(integration, url, request_params["personal"])
      when 'name'
        url = "v1/identity/#{integration.company_code}/#{user.trinet_id}/names"
        @response =  execute_update(integration, url, request_params["name"])
      end
      
      if @response.code.to_s == '200'
        create_loggings(company, @integration, 'Trinet', @response.code, "Update user in Trinet - Success", {response: @response.body}, {params: request_params}.inspect)
        log_statistics('success', company)
      else
        create_loggings(company, @integration, 'Trinet', @response.code, "Update user in Trinet - Failure", {response: @response.body}, {params: request_params}.inspect)
        log_statistics('success', company)
      end
    rescue Exception => e
      create_loggings(company, @integration, 'Trinet', 500, "Update user in Trinet - Failure", {response: e}, {params: request_params}.inspect)
      log_statistics('failed', company)
    end
  end

  def helper_service
    HrisIntegrationsService::Trinet::Helper.new
  end

  def endpoint_service
    HrisIntegrationsService::Trinet::Endpoint.new
  end
end	