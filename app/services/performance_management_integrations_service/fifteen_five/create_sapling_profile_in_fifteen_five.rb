class PerformanceManagementIntegrationsService::FifteenFive::CreateSaplingProfileInFifteenFive
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
    create
  end

  private
  
  def create
    request_data = @data_builder.build_create_profile_data(@user)
    request_params = @params_builder.build_create_profile_params(request_data)

    return unless request_params.present?

    begin
      response = HTTParty.post("https://#{integration.subdomain}.15five.com/scim/v2/Users",
        body: request_params.to_json,
        headers: { 'Accept' => 'application/scim+json', 'Content-Type' => 'application/scim+json', 'Authorization' => "Bearer #{integration.access_token}" }
      )

      if response.created?
        parsed_response = JSON.parse(response.body)
        user.update_column(:fifteen_five_id, parsed_response['id'])
        create_loggings(@company, 'Fifteen Five', response.code, "Create user in fifteen five - Success", {response: parsed_response}, {data: request_data, params: request_params})
        log_statistics('success', @company, integration)
      else
        create_loggings(@company, 'Fifteen Five', response.code, "Create user in fifteen five - Failure", {response: response.inspect}, {data: request_data, params: request_params})
        log_statistics('failed', @company, integration)
      end
    rescue Exception => e
      create_loggings(@company, 'Fifteen Five', 500, "Create user in fifteen five - Failure", {response: e.message}, {data: request_data, params: request_params})
      log_statistics('failed', @company, integration)
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::FifteenFive::Helper.new
  end
end