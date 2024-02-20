class SsoIntegrationsService::ActiveDirectory::CreateSaplingProfileInActiveDirectory
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, to: :helper_service
  delegate :log_success_hris_statistics, :log_failed_hris_statistics, to: :integration_statistic_management_service

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
      response = HTTParty.post("https://graph.microsoft.com/beta/users",
        body: request_params.to_json,
        headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json', 'Authorization' => "Bearer #{integration.access_token}" }
      )
      
      parsed_response = JSON.parse(response.body)

      if response.created?
        @user.update_columns(active_directory_object_id: parsed_response['id'], active_directory_initial_password: request_params[:passwordProfile][:password])
        
        log('success', response.code, "Create user-#{@user.id} in active directory - Success", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        @user.reload.send_provising_credentials
      else
        log('failed', response.code, "Create user-#{@user.id} in active directory - Failure", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
      end
    rescue Exception => e
      log('failed', 500, "Create user-#{@user.id} in active directory - Failure", {response: e}, {data: request_data, params: request_params}.inspect)
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