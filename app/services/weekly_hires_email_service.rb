class WeeklyHiresEmailService

  def initialize(alert)
    @alert = alert
  end

  def perform
    process_alert
  end

  def test(user)
    recipients = [user.email]
    new_hires = [
      { url: "", avatar: "https://static.diverseui.com/male-12.jpg", name: "Richard Alvarez", title: "Engineering Manager", location: "Lima", team: "R&D" },
      { url: "", avatar: "https://static.diverseui.com/male-17.jpg", name: "Harold Lane", title: "Accountant", location: "London", team: "Finance" },
      { url: "", avatar: "https://static.diverseui.com/female-4.jpg", name: "Brooklyn Watson", title: "Account Executive", location: "London", team: "Sales" },
      { url: "", avatar: "https://static.diverseui.com/180ef954-bbe4-4bef-bb2d-b23142433915-avatar.jpeg", name: "Kathleen Nguyen", title: "Customer Support", location: "Los Angeles", team: "Support" },
      { url: "", avatar: "https://static.diverseui.com/female-61.jpg", name: "Marissa Ramos", title: "UX Designer", location: "Lima", team: "R&D" }
    ]
    UserMailer.weekly_new_hires_email(@alert, new_hires, recipients, true).deliver_now! unless recipients.empty?
  end

  private

  def process_alert
    new_hires = get_hires
    admin_recipients, non_admin_recipients = CustomEmailAlertService.new.retrieve_alert_recipients(@alert)
    if !new_hires.empty?
      UserMailer.weekly_new_hires_email(@alert, new_hires, admin_recipients, true).deliver_now! unless admin_recipients.empty?
      UserMailer.weekly_new_hires_email(@alert, new_hires, non_admin_recipients, false).deliver_now! unless non_admin_recipients.empty?
    end
  end

  def get_hires
    company = @alert.company
    today = Date.today.in_time_zone(company.time_zone).to_date
    cutoff_date = today + 6.days
    users = company.users.where(super_user: false, start_date: today..cutoff_date).where.not("current_stage IN (?)", [User.current_stages[:incomplete], User.current_stages[:departed]])
    if !@alert.applied_to_teams.include?("all")
      users = users.where("users.team_id IN (?)", @alert.applied_to_teams.map(&:to_i))
    end
    if !@alert.applied_to_locations.include?("all")
      users = users.where("users.location_id IN (?)", @alert.applied_to_locations.map(&:to_i))
    end
    if !@alert.applied_to_statuses.include?("all")
      custom_field = @alert.company.custom_fields.where(name: 'Employment Status', field_type: CustomField.field_types[:employment_status]).take
      custom_field_option_ids = custom_field.custom_field_options.where(option: @alert.applied_to_statuses).pluck(:id)
      users = users.joins(:custom_field_values).where('custom_field_values.custom_field_id = ? AND custom_field_values.custom_field_option_id IN (?) AND custom_field_values.user_id = users.id', custom_field.id, custom_field_option_ids)
    end
    hires = users.map do |hire|
      {
        url: "https://#{company.app_domain}/#/profile/#{hire.id}",
        avatar: hire.picture || "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTkF8Lw_tDKvUUjFCbFmAcDQFqAS2IHXX8ncf1HsqdIzMGW7QjT8g",
        name: hire.display_name,
        title: hire.title || "",
        location: hire.location.try(:name) || "",
        team: hire.team.try(:name) || ""
      }
    end
    hires
  end

end
