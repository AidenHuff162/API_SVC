class SendEmployeeToAdpWorkforceNowJob < ApplicationJob
  queue_as :add_employee_to_adp

  def perform(user_id)
    user = User.find_by_id(user_id)
    ::HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp.new(user).create if user
  end
end
