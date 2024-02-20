module PeriodicJobs::Reports
  class SendScheduledReports
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Reports::SendScheduledReports').ping_start
      ::ScheduleReportJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Reports::SendScheduledReports').ping_ok
    end
  end
end
