class RoiEmailManagementServices::WeeklyMetricsEmail
  attr_reader :alert, :statistics

  def initialize(alert)
    @alert = alert
  end

  def perform(statistics)
    @statistics = statistics
    trigger_custom_alert
  end

  def test(user)
    recipients = [(user.email || user.personal_email)]
    # statistics = build_test_statistics()
    
    date = ((Date.today+9.days).in_time_zone(@alert.company.time_zone).to_date.at_beginning_of_week) - 1.day
    statistics = ::RoiEmailManagementServices::CalculateWeeklyStatistics.new(@alert.company, date).perform
    
    UserMailer.weekly_metrics_email(@alert, statistics, recipients, true).deliver_now! if recipients.present?
  end

  private

  def filter_recipients(recipients)
    return unless recipients.present? && @alert.applied_to_teams.present? && @alert.applied_to_locations.present? && @alert.applied_to_statuses.present?
    return recipients if @alert.applied_to_teams.include?('all') && @alert.applied_to_locations.include?('all') && @alert.applied_to_statuses.include?('all')
    
    filtered_recipients = @alert.company.users.where(email: recipients)
    return unless filtered_recipients.present?
  
    if @alert.applied_to_teams.exclude?('all')
      filtered_recipients = filtered_recipients.where(team_id: @alert.applied_to_teams)
    end

    if @alert.applied_to_locations.exclude?('all')
      filtered_recipients = filtered_recipients.where(location_id: @alert.applied_to_locations)
    end

    if @alert.applied_to_statuses.exclude?('all')
      custom_field = @alert.company.custom_fields.where(name: 'Employment Status', field_type: CustomField.field_types[:employment_status]).take
      custom_field_option_ids = custom_field.custom_field_options.where(option: @alert.applied_to_statuses).pluck(:id)
      filtered_recipients = filtered_recipients.joins(:custom_field_values).where('custom_field_values.custom_field_id = ? AND custom_field_values.custom_field_option_id IN (?) AND custom_field_values.user_id = users.id', custom_field.id, custom_field_option_ids)
    end

    filtered_recipients.pluck(:email).compact
  end

  def fetch_recipients
    admin_recipients, non_admin_recipients = CustomEmailAlertService.new.retrieve_alert_recipients(@alert)
    
    admin_recipients = filter_recipients(admin_recipients.compact)
    non_admin_recipients = filter_recipients(non_admin_recipients.compact)

    return admin_recipients, non_admin_recipients
  end

  def trigger_custom_alert
    admin_recipients, non_admin_recipients = fetch_recipients

    UserMailer.weekly_metrics_email(@alert, @statistics, admin_recipients, true).deliver_now! if admin_recipients.present?
    UserMailer.weekly_metrics_email(@alert, @statistics, non_admin_recipients, false).deliver_now! if non_admin_recipients.present?
  end

  def build_test_statistics
    {
      onboarded_users_count: 20,
      logged_in_users_count: 56,
      signed_documents_count: 200,
      assigned_tasks_count: 150,
      assigned_ptos_count: 34,
      records_updated_count: 650,
      api_call_processed_count: 24500,
      live_integrations_count: 4
    }
  end
end