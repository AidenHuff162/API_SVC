class SendUpdatedEmployeeToAdpWorkforceNowJob < ApplicationJob
  include IntegrationFilter
  queue_as :update_employee_to_adp

  def perform(user_id, field_name=nil, field_id=nil, value=nil)
    user = User.find_by_id(user_id)
    ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).update(field_name, value, field_id) if user
  end
end
