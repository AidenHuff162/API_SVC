module PeriodicJobs::Emails
  class WeeklyMetricsEmail
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyMetricsEmail').ping_start
      
      companies = fetch_companies

      companies.find_each do |company|
        datetime = (Time.now.in_time_zone(company.time_zone).to_date.at_end_of_week + 1.day).in_time_zone(company.time_zone) + 8.hours
        jid = ::WeeklyMetricsJob.perform_at(datetime, company.id)

        company.update_column(:metrics_email_job_id, jid) if jid.present?
      end
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyMetricsEmail').ping_ok
    end

    private

    def fetch_companies
      Company.joins(:custom_email_alerts).where('custom_email_alerts.alert_type = ? AND custom_email_alerts.is_enabled = ?', CustomEmailAlert.alert_types[:weekly_metrics], true)
    end
  end
end
