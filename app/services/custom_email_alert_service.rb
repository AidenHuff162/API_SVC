class CustomEmailAlertService
  attr_reader :company

  def manage_time_off_custom_alert(pto_request_id, negative_balance_alert)
    @negative_balance_alert = negative_balance_alert
    pto_request = PtoRequest.find_by(id: pto_request_id)
    return unless pto_request.present?

    @company = pto_request.user.company
    dispatch_time_off_custom_alerts(pto_request)
  end

  def manage_offboarding_custom_alert(company_id, user_id, employee_id)
    @company = Company.find(company_id)
    return unless @company.present?

    action_performer = @company.users.find_by(id: user_id)
    return unless action_performer.present?

    employee = @company.users.find_by(id: employee_id)
    return unless employee.present?

    dispatch_offboarding_custom_alerts(action_performer, employee)
  end

  def retrieve_alert_recipients(alert)
    recipients = fetch_custom_alert_receivers(alert, nil)
    admin_recipients = recipients.joins(:user_role).where(user_roles: {role_type: [2, 3]}).where.not(email: nil)
    non_admin_recipients = recipients.where.not(id: admin_recipients.try(:ids), email: nil)
    return admin_recipients.pluck(:email), non_admin_recipients.pluck(:email)
  end

  def create_default_custom_alerts(company)
    default_alert_data = {
      timeoff_approved: { title: "Time Off Request Approved", subject: "Time Off Request Approved", is_enabled: false, body: "'s time off request has been approved." },
      timeoff_requested: { title: "New Time Off Request", subject: "New Time Off Request", is_enabled: false, body: ' requested time off' },
      timeoff_denied: { title: "Time Off Request Denied", subject: "Time Off Request Denied", is_enabled: false, body: "'s time off request has been denied." },
      timeoff_canceled: { title: "Time Off Request Canceled", subject: "Time Off Request Canceled", is_enabled: false, body: "'s time off request has been canceled." },
      termination: { title: "New Termination in Sapling", subject: "New Termination in Sapling", is_enabled: false,  body: "'s offboarding has been initiated."},
      new_hires: { title: "New Hire Announcement", subject: "Warm welcome to our new hires this week  🎉 🎉 🎉", is_enabled: true },
      negative_balance: { title: "Negative PTO Balance Alert", subject: "Negative PTO Balance Alert", is_enabled: false, body: "<p><span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Display Name\">Display Name</span>‌ a <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Job Title\">Job Title</span>‌ in <span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Location\">Location</span>‌, recently requested time off&#40;<span class=\"token\" contenteditable=\"false\" unselectable=\"on\" data-name=\"Policy Name\">Policy Name</span>‌&#41; &#97;&#110;&#100; now has a negative balance.</p>" },
      weekly_metrics: { title: "Sapling Weekly Metrics", subject: "Sapling Weekly Metrics", is_enabled: true },
    }
    CustomEmailAlert.alert_types.each do |alert_type, v|
      unless company.custom_email_alerts.find_by(alert_type: alert_type).present?
        alert = company.custom_email_alerts.new
        alert.alert_type = alert_type
        alert_type = alert_type.to_sym
        alert.title = default_alert_data[alert_type][:title]
        alert.subject = default_alert_data[alert_type][:subject]
        alert.body = default_alert_data[alert_type][:body]
        alert.applied_to_teams = ["all"]
        alert.applied_to_locations = ["all"]
        alert.applied_to_statuses = ["all"]
        alert.notified_to = 0
        alert.is_enabled = default_alert_data[alert_type][:is_enabled]
        alert.notifiers = company.user_roles.where(role_type: [2, 3]).where.not(name: ["Ghost Admin", "Temp Admin"]).pluck(:id).map(&:to_s)
        alert.save
      end
    end
  end

  private

  def get_time_off_alert_type(pto_request)
    if @negative_balance_alert
      return CustomEmailAlert.alert_types[:negative_balance]
    elsif pto_request.pending?
      return CustomEmailAlert.alert_types[:timeoff_requested]
    elsif pto_request.approved?
      return CustomEmailAlert.alert_types[:timeoff_approved]
    elsif pto_request.cancelled?
      return CustomEmailAlert.alert_types[:timeoff_canceled]
    elsif pto_request.denied?
      return CustomEmailAlert.alert_types[:timeoff_denied]
    end
  end

  def fetch_time_off_custom_alerts(pto_request)
    alert_type = get_time_off_alert_type(pto_request)
    return unless alert_type.present?

    fetch_custom_alerts(alert_type, pto_request.user)
  end

  def fetch_offboarding_custom_alerts(user)
    fetch_custom_alerts(CustomEmailAlert.alert_types[:termination], user)
  end

  def fetch_custom_alerts(alert_type, user)
    company.custom_email_alerts.where("alert_type = ? AND (('all' = ANY (applied_to_teams)) OR (? = ANY (applied_to_teams)))
      AND (('all' = ANY (applied_to_locations)) OR (? = ANY (applied_to_locations))) AND (('all' = ANY (applied_to_statuses))
      OR (? = ANY (applied_to_statuses)))", alert_type, user.team_id.try(:to_s), user.location_id.try(:to_s),
      user.employee_type.try(:to_s))
  end

  def fetch_custom_alert_receivers(custom_email_alert, employee)
    company ||= custom_email_alert.company
    if custom_email_alert.individual?
      return company.users.where(id: custom_email_alert.notifiers, state: 'active').where.not('current_stage = ?', User.current_stages[:departed])
    else
      if custom_email_alert.notifiers.include?('all')
        if employee.try(:id).present?
          return company.users.where(state: 'active').where.not('users.id = ? OR current_stage = ?', employee.try(:id), User.current_stages[:departed])
        else
          return company.users.where(state: 'active').where.not('current_stage = ?', User.current_stages[:departed])
        end
      else
        if employee.try(:id).present?
          return company.users.where(user_role_id: custom_email_alert.notifiers, state: 'active').where.not('users.id = ? OR current_stage = ?', employee.try(:id), User.current_stages[:departed])
        else
          return company.users.where(user_role_id: custom_email_alert.notifiers, state: 'active').where.not('current_stage = ?', User.current_stages[:departed])
        end
      end
    end
  end

  def dispatch_time_off_custom_alerts(pto_request)
    custom_email_alerts = fetch_time_off_custom_alerts(pto_request)
    return unless custom_email_alerts.present?

    custom_email_alerts.try(:each) do |custom_email_alert|
      next if !custom_email_alert.is_enabled?
      users = fetch_custom_alert_receivers(custom_email_alert, pto_request.user)
      users.try(:each) do  |user|
        if @negative_balance_alert
          TimeOffMailer.send_negative_balance_alert(custom_email_alert, user, pto_request).deliver_now!
        else
          TimeOffMailer.time_off_custom_alert(custom_email_alert, user, pto_request).deliver_now!
        end
      end
    end
  end

  def dispatch_offboarding_custom_alerts(action_performer, employee)
    custom_email_alerts = fetch_offboarding_custom_alerts(employee)
    return unless custom_email_alerts.present?

    custom_email_alerts.try(:each) do |custom_email_alert|
      next if !custom_email_alert.is_enabled?
      users = fetch_custom_alert_receivers(custom_email_alert, employee)
      users.try(:each) do |user|
        UserMailer.terminated_custom_alert(action_performer, user, employee, custom_email_alert).deliver_now!
      end
    end
  end

end
