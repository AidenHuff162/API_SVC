class WeeklyMetricsJob
  include Sidekiq::Worker
  sidekiq_options :queue => :weekly_metrics, :retry => false, :backtrace => true

  def perform(company_id)
    company = Company.find_by_id(company_id)
    return unless company.present?
    
    company.update_column(:metrics_email_job_id, nil)

    trigger_weekly_metrics_email(company)
  end

  private

  def build_statistics(company)
    date = (Date.today.in_time_zone(company.time_zone).to_date.at_beginning_of_week) - 1.day
    ::RoiEmailManagementServices::CalculateWeeklyStatistics.new(company, date).perform
  end

  def trigger_weekly_metrics_email(company)
    custom_alerts = company.custom_email_alerts.where(alert_type: CustomEmailAlert.alert_types[:weekly_metrics], is_enabled: true)
    return unless custom_alerts.present?

    statistics = build_statistics(company)

    custom_alerts.each do |custom_alert|
      ::RoiEmailManagementServices::WeeklyMetricsEmail.new(custom_alert).perform(statistics)
    end
  end
end