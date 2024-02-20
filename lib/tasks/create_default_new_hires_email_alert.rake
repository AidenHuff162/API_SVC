namespace :create_default_new_hires_email_alert do

  task create_default_new_hires_email_alert: :environment do
    has_template = Company.joins(:custom_email_alerts).where(custom_email_alerts: { alert_type: CustomEmailAlert.alert_types[:new_hires] }).pluck(:id)
    companies = Company.where(subdomain: ["aclara", "invision", "addepar", "asana", "digitalocean", "beat"]).where.not(id: has_template)
    companies.each do |company|
      new_hire_alert = company.custom_email_alerts.new
      new_hire_alert.alert_type = CustomEmailAlert.alert_types[:new_hires]
      new_hire_alert.title = 'New Hire Announcement'
      new_hire_alert.subject = 'Warm welcome to our new hires this week  🎉 🎉 🎉'
      new_hire_alert.applied_to_teams = ["all"]
      new_hire_alert.applied_to_locations = ["all"]
      new_hire_alert.applied_to_statuses = ["Full Time"]
      new_hire_alert.notified_to = 0
      new_hire_alert.notifiers = company.user_roles.where(role_type: [2, 3]).where.not(name: ["Ghost Admin", "Temp Admin"]).pluck(:id).map(&:to_s)
      new_hire_alert.save
    end
  end

end
