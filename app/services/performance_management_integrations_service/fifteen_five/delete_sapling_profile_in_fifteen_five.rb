class PerformanceManagementIntegrationsService::FifteenFive::DeleteSaplingProfileInFifteenFive
  attr_reader :company, :user, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service

  def initialize(company, user, integration)
    @company = company
    @user = user
    @integration = integration
  end

  def perform
    delete
  end

  private

  def delete
    begin
      response = HTTParty.delete("https://#{integration.subdomain}.15five.com/scim/v2/Users/#{user.fifteen_five_id}",
        headers: { 'Authorization' => "Bearer #{integration.access_token}" }
      )

      if response.no_content?
        # user.update_column(:fifteen_five_id, nil)
        create_loggings(@company, 'Fifteen Five', response.code, "Delete user in fifteen five - Success", {response: response}, {data: user.fifteen_five_id})
        log_statistics('success', @company, integration)
      else
        create_loggings(@company, 'Fifteen Five', response.code, "Delete user in fifteen five - Failure", {response: response}, {data: user.fifteen_five_id})
        log_statistics('failed', @company, integration)
      end
    rescue Exception => e
      create_loggings(@company, 'Fifteen Five', 500, "Delete user in fifteen five - Failure", {response: e.message}, {data: user.fifteen_five_id})
      log_statistics('failed', @company, integration)
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::FifteenFive::Helper.new
  end
end

