class CustomAlerts::TerminatedCustomAlertJob < ApplicationJob
  queue_as :manage_custom_alert

  def perform(company_id, user_id, employee_id)
    CustomEmailAlertService.new.manage_offboarding_custom_alert(company_id, user_id, employee_id)
  end
end
