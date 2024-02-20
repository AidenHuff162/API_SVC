class HrisIntegrationsService::Deputy::CreateSaplingProfileInDeputy
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, to: :helper_service

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
    request_params = @params_builder.build_create_profile_params(request_data, @integration.can_invite_profile.present?)

    return unless request_params.present?

    begin
      response = HTTParty.post("https://#{integration.subdomain}/api/v1/supervise/employee",
        body: request_params.to_json,
        headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)

      if response.ok?
        if @company.users.exists?(deputy_id: parsed_response['Id']).blank?
          @user.update_column(:deputy_id, parsed_response['Id'])
          
          create_loggings(@company, 'Deputy', response.code, "Create user in deputy - Success", {response: parsed_response}, {data: request_data, params: request_params})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          create_loggings(@company, 'Deputy', response.code, "Create user in deputy - Failure", {response: parsed_response, message: 'User already exist with same information in deputy, please change information'}, {data: request_data, params: request_params})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      else
        create_loggings(@company, 'Deputy', response.code, "Create user in deputy - Failure", {response: parsed_response}, {data: request_data, params: request_params})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Create user in deputy - Failure", {response: e.message}, {data: request_data, params: request_params})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end