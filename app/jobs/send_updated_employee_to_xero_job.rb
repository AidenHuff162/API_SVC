class SendUpdatedEmployeeToXeroJob < ApplicationJob
  queue_as :update_employee_to_hr

  def perform(user_id, attributes)
    user = User.find_by(id: user_id)
    return unless user&.super_user?.blank? && user.xero_id.present? && user.company.is_xero_integrated?
    HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('update', attributes) 
  end
end
