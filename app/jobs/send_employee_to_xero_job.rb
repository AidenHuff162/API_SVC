class SendEmployeeToXeroJob < ApplicationJob
  queue_as :add_employee_to_hr

  def perform(user_id)
    user = User.find_by(id: user_id)

    return unless user&.super_user?.blank? && user.xero_id.blank? && user.company.is_xero_integrated?
    HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('create')
  end
end
