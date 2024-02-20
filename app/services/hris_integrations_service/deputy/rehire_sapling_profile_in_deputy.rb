class HrisIntegrationsService::Deputy::RehireSaplingProfileInDeputy
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, to: :helper_service

  def initialize(company, user, integration, data_builder = nil, params_builder = nil)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
  end

  def perform(can_update = false)
    
    is_rehired = rehire
    update_rehired if is_rehired.present? && can_update.present?
  end

  private

  def rehire
    begin
      response = HTTParty.post("https://#{integration.subdomain}/api/v1/supervise/employee/#{@user.deputy_id}/activate",
        headers: { accept: 'application/json', authorization: "Bearer #{@integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)

      if response.ok?
        create_loggings(@company, 'Deputy', response.code, "Rehire/Activate user in deputy - Success", {response: parsed_response}, {data: @user.deputy_id})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        return true
      else
        create_loggings(@company, 'Deputy', response.code, "Rehire/Activate user in deputy - Failure", {response: parsed_response}, {data: @user.deputy_id})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Rehire/Activate user in deputy - Failure", {response: e.message}, {data: @user.deputy_id})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end

    return false
  end

  def update_rehired
    request_data = @data_builder.build_rehire_profile_data(@user)
    request_params = @params_builder.build_rehire_profile_params(request_data, @integration.can_invite_profile.present?)

    begin
      response = HTTParty.post("https://#{@integration.subdomain}/api/v1/supervise/employee/#{@user.deputy_id}",
        body: request_params.to_json,
        headers: { accept: 'application/json', content_type: 'application/json', authorization: "Bearer #{@integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)

      if response.ok? 
        if @user.deputy_id == parsed_response['Id'].to_s
          create_loggings(@company, 'Deputy', response.code, "Updated Rehired/Activated user in deputy - Success", {response: parsed_response}, {data: @user.deputy_id})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
        else
          create_loggings(@company, 'Deputy', response.code, "Updated Rehired/Activated user in deputy - Failure", {response: parsed_response, message: 'User already exist with same information in deputy, please change information'}, {data: request_data, params: request_params})
          ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
        end
      else
        create_loggings(@company, 'Deputy', response.code, "Updated Rehired/Activated user in deputy - Failure", {response: parsed_response}, {data: @user.deputy_id})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Updated Rehired/Activated user in deputy - Failure", {response: e.message}, {data: @user.deputy_id})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end