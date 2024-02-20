class SsoIntegrationsService::ActiveDirectory::UpdateSaplingProfileInActiveDirectory
  attr_reader :company, :user, :integration, :data_builder, :params_builder, :attributes

  delegate :create_loggings, to: :helper_service
  delegate :log_success_hris_statistics, :log_failed_hris_statistics, to: :integration_statistic_management_service

  def initialize(company, user, integration, data_builder, params_builder, attributes)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
    @attributes = attributes.map(&:downcase)
  end

  def perform
    update
  end

  private

  def update
    update_attributes
  end

  def update_attributes
    request_data = @data_builder.build_update_profile_data(@user, @attributes)
    request_params = @params_builder.build_update_profile_params(request_data)

    return unless request_params.present?

    begin
      response = HTTParty.patch("https://graph.microsoft.com/beta/users/#{user.active_directory_object_id}",
        body: request_params.to_json,
        headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{integration.access_token}" }
      )

      if response.no_content?
        log('success', response.code, "Update user-#{@user.id} in active directory - Success", {response: response}, {data: request_data, params: request_params}.inspect)
      else
        log('failed', response.code, "Update user-#{@user.id} in active directory - Failure", {response: response}, {data: request_data, params: request_params}.inspect)
      end
    rescue Exception => e
      log('failed', 500, "Update user-#{@user.id} in active directory - Failure", {response: e}, {data: request_data, params: request_params}.inspect)
    end
  end

  def log(state, status, action, result, request = nil)
    create_loggings(@company, 'Active Directory', status, action, {result: result}, request)

    if state == 'success'
      log_success_hris_statistics(@company)
    else
      log_failed_hris_statistics(@company)
    end
  end

  def helper_service
    ::SsoIntegrationsService::ActiveDirectory::Helper.new
  end

  def integration_statistic_management_service
    ::RoiManagementServices::IntegrationStatisticsManagement.new
  end
end