FactoryGirl.define do
  factory :custom_email_alert do
    alert_type { CustomEmailAlert.alert_types[:timeoff_approved] }
    notified_to { CustomEmailAlert.notified_tos[:permission_group] }
    title 'Time Off Approved'
    subject 'Time Off Approved'
    body 'time off request has been approved in Sapling.'
    applied_to_teams ['all']
    applied_to_locations ['all']
    applied_to_statuses ['all']
    notifiers ['all']
    is_enabled true
    
    company
  end

  factory :negative_balance_alert, parent: :custom_email_alert do
    alert_type { CustomEmailAlert.alert_types[:negative_balance] }
    title ' '
    subject 'Negative Balance'
    body 'balance is negative now'
    company
  end

  factory :custom_email_alert_create, parent: :custom_email_alert do
    alert_type { CustomEmailAlert.alert_types[:timeoff_requested] }
    title 'Requestedd'
    subject 'Requested'
    body 'requested'
    company
  end

  factory :custom_email_alert_weekly_metrics, parent: :custom_email_alert do
    alert_type { CustomEmailAlert.alert_types[:weekly_metrics] }
    title 'Requestedd'
    subject 'Requested'
    body 'requested'
    company
  end
end
