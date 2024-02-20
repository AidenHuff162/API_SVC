module PeriodicJobs::Emails
  class WeeklyHiresEmail
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyHiresEmail').ping_start
      ::WeeklyHiresEmailJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::WeeklyHiresEmail').ping_ok
    end
  end
end
