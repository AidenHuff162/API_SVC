class HrisIntegrationsService::Deputy::UpdateSaplingProfileInDeputy
  attr_reader :company, :user, :integration, :data_builder, :params_builder, :attributes

  delegate :create_loggings, :notify_slack, to: :helper_service

  def initialize(company, user, integration, data_builder, params_builder, attributes = nil)
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

    return unless request_params.present?

    begin
      response = HTTParty.post("https://#{@integration.subdomain}/api/v1/supervise/employee/#{@user.deputy_id}",
        body: request_params.to_json,
        headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{@integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)
      if response.ok?
        if @user.deputy_id == parsed_response['Id'].to_s
          create_loggings(@company, 'Deputy', response.code, "Update user in deputy - Success", {response: parsed_response}, {data: request_data, params: request_params})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          create_loggings(@company, 'Deputy', response.code, "Update user in deputy - Failure", {response: parsed_response, message: 'User already exist with same information in deputy, please change information'}, {data: request_data, params: request_params})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      else
        create_loggings(@company, 'Deputy', response.code, "Update user in deputy - Failure", {response: parsed_response}, {data: request_data, params: request_params})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Update user in deputy - Failure", {response: e.message}, {data: request_data, params: request_params})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end