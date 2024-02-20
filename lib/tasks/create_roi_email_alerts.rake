namespace :create_roi_email_alerts do

  task create_roi_email_alerts: :environment do
    has_template = Company.joins(:custom_email_alerts).where(custom_email_alerts: { alert_type: CustomEmailAlert.alert_types[:weekly_metrics] }).pluck(:id)
    companies = Company.where.not(id: has_template).where.not(subdomain: "aclara")
    companies.each do |company|
      roi_alert = company.custom_email_alerts.new
      roi_alert.alert_type = CustomEmailAlert.alert_types[:weekly_metrics]
      roi_alert.title = 'Sapling Weekly Metrics'
      roi_alert.subject = 'Sapling Weekly Metrics'
      roi_alert.applied_to_teams = ["all"]
      roi_alert.applied_to_locations = ["all"]
      roi_alert.applied_to_statuses = ["all"]
      roi_alert.notified_to = 0
      roi_alert.notifiers = company.user_roles.where(role_type: 3).where.not(name: ["Ghost Admin", "Temp Admin"]).pluck(:id).map(&:to_s)
      roi_alert.is_enabled = true
      roi_alert.save
    end
  end

end
