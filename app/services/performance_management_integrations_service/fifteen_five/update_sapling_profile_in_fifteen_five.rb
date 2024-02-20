class PerformanceManagementIntegrationsService::FifteenFive::UpdateSaplingProfileInFifteenFive
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, to: :helper_service

  def initialize(company, user, integration, data_builder, params_builder)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
  end

  def perform
    update
  end

  private
  
  def update
    update_by_scim
    # update_by_api if updated_attributes.include?('department')
  end

  def update_by_scim
    request_data = @data_builder.build_update_profile_data(@user, 'scim')
    request_params = @params_builder.build_update_profile_params(request_data)

    begin
      response = HTTParty.put("https://#{integration.subdomain}.15five.com/scim/v2/Users/#{user.fifteen_five_id}",
        body: request_params.to_json,
        headers: { 'Accept' => 'application/scim+json', 'Content-Type' => 'application/scim+json', 'Authorization' => "Bearer #{integration.access_token}" }
      )

      if response.ok?
        create_loggings(@company, 'Fifteen Five', response.code, "Update user in fifteen five (SCIM) - Success", {response: response}, {data: request_data, params: request_params})
        log_statistics('success', @company, integration)
      else
        create_loggings(@company, 'Fifteen Five', response.code, "Update user in fifteen five (SCIM) - Failure", {response: response}, {data: request_data, params: request_params})
        log_statistics('failed', @company, integration)
      end
    rescue Exception => e
      create_loggings(@company, 'Fifteen Five', 500, "Update user in fifteen five - Failure", {response: e.message}, {data: request_data, params: request_params})
      log_statistics('failed', @company, integration)
    end
  end

  def update_by_api
  end

  def helper_service
    PerformanceManagementIntegrationsService::FifteenFive::Helper.new
  end
end