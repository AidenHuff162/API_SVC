class CustomAlerts::TimeOffCustomAlertJob < ApplicationJob
  queue_as :manage_custom_alert

  def perform(pto_request_id, negative_balance_alert=false)
    CustomEmailAlertService.new.manage_time_off_custom_alert(pto_request_id, negative_balance_alert)
  end
end
