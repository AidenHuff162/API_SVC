class HrisIntegrationsService::Xero::CreateSaplingProfileInXero
  attr_reader :user, :company, :params_builder_service, :xero
  delegate :create_loggings, to: :helper_service
  delegate :post_request, to: :hris_service

  def initialize(user, xero)
    @user = user
    @company = user.company
    @xero = xero
    initialize_service
  end

  def create_profile
    params = params_builder_service.build_onboard_params(user, xero)

    begin
      response = post_request(params)
      if response.ok?
        body = JSON.parse(response.body)
        user.update_column(:xero_id, body["Employees"][0]["EmployeeID"])
        log(response.code, 'Create Profile in Xero - SUCCESS', { params: params, result: body }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        log(response.code, 'Create Profile in Xero - Failure', { params: params, message: response.message, response: response.body.to_s, effected_profile: "#{user.full_name} (#{user.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, 'Create Profile in Xero - Failure', { message: e.message, params: params, effected_profile: "#{user.full_name} (#{user.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  private
  
  def initialize_service
    @params_builder_service = HrisIntegrationsService::Xero::ParamsBuilder.new
  end 

  def log(status, action, result, request = nil)
    create_loggings(company, "Xero", status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end
  
  def hris_service
    HrisIntegrationsService::Xero::HumanResource.new(company, nil, @user.id)
  end 
end
