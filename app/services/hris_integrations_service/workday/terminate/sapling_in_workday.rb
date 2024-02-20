class HrisIntegrationsService::Workday::Terminate::SaplingInWorkday < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  include HrisIntegrationsService::Workday::Exceptions

  attr_reader :user, :operation_name, :company

  delegate :termination_stages, to: :helper_service
  delegate :prepare_request, :sync_workday, to: :web_service

  def initialize(user)
    @user = user
    @company = user.company # for logging module
    @operation_name = get_operation_name
  end

  def call
    terminate_employee if user.departed?
  end

  private

  def terminate_employee
    begin
      params = { user: user, termination_reason: get_termination_reason }
      request_params = request_params_builder.call(operation_name, params)
      response = prepare_request(operation_name, request_params, 'staffing')
      termination_log(response.http.code, request_params, response)
      sync_workday
    rescue Exception => @error
      error_log("Unable to terminate user with id: (#{user.id}) in Workday",
                { response: response&.body }, api_action(operation_name, request_params))
    end
  end

  def request_params_builder
    HrisIntegrationsService::Workday::ParamsBuilder::Workday
  end

  def helper_service
    HrisIntegrationsService::Workday::Helper.new
  end

  def web_service
    HrisIntegrationsService::Workday::WebService.new(user.company_id)
  end

  def termination_log(status_code, request_params, response)
    action = "#{log_result(status_code)} terminate user with id: #{user.id} in Workday"
    log(action, { response: response.body }, api_action(operation_name, request_params), status_code)
    (status_code == 500) && send_to_teams(action)
  end

  def get_termination_reason
    reason = user.get_custom_field_value_workday_wid('Workday Termination Reason')
    validate_presence!('Workday Termination Reason', reason)
    reason
  end

  def get_operation_name
    user.workday_id_type == 'Employee_ID' ? 'terminate_employee' : 'end_contingent_worker_contract'
  end

end
