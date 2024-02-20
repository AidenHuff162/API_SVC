class HrisIntegrationsService::Deputy::DeleteSaplingProfileInDeputy
  attr_reader :company, :user, :integration

  delegate :create_loggings, :notify_slack, to: :helper_service

  def initialize(company, user, integration)
    @company = company
    @user = user
    @integration = integration
  end

  def perform
    begin
      response = HTTParty.post("https://#{integration.subdomain}/api/v1/supervise/employee/#{@user.deputy_id}/delete",
        headers: { accept: 'application/json', authorization: "Bearer #{@integration.access_token}" }
      )
      
      if response.ok?      
        create_loggings(@company, 'Deputy', response.code, "Delete user in deputy - Success", {response: 'Deleted User'}, {data: @user.deputy_id})
        
        @user.update_column(:deputy_id, nil)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        create_loggings(@company, 'Deputy', response.code, "Delete user in deputy - Failure", {response: JSON.parse(response.body)}, {data: @user.deputy_id})
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      create_loggings(@company, 'Deputy', 500, "Delete user in deputy - Failure", {response: e.message}, {data: @user.deputy_id})
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  private

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end