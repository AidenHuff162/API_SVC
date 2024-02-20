class HrisIntegrationsService::Xero::CreateLeaveTypesInXero
  attr_reader :policy, :company, :params_builder_service
  delegate :create_loggings, to: :helper_service
  delegate :create_leave_types, :fetch_leave_types, to: :hris_service

  def initialize(policy)
    @policy = policy
    @company = policy.company
    @params_builder_service = HrisIntegrationsService::Xero::ParamsBuilder.new
  end

  def create_leave_type
    begin
      leave_types = fetch_leave_types
      params = params_builder_service.build_leave_type_params(policy, leave_types)
      response = create_leave_types(params)
      if response.ok?
        body = JSON.parse(response.body)
        policy.update_column(:xero_leave_type_id, body["PayItems"]["LeaveTypes"][body["PayItems"]["LeaveTypes"].length-1]["LeaveTypeID"])
        log(response.code, 'Create Leave Type in Xero - SUCCESS', { params: params, result: body }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(@company)
      else
        log(response.code, 'Create Leave Type in Xero - Failure', { params: params, message: response.message, response: response.body.to_s, effected_profile: "#{policy.name} (#{policy.id})" }, params)
        ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
      end
    rescue Exception => e
      log(500, 'Create Leave Type in Xero - Failure', { message: e.message, params: params, effected_profile: "#{policy.name} (#{policy.id})" }, params)
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(@company)
    end
  end

  private
  
  def log(status, action, result, request = nil)
    create_loggings(company, "Xero", status, action, result, request)
  end

  def helper_service
    HrisIntegrationsService::Xero::Helper.new
  end
  
  def hris_service
    HrisIntegrationsService::Xero::HumanResource.new company
  end 
end
