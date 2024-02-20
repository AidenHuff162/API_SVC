module PeriodicJobs
  class FixCounters
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::FixCounters').ping_start
      ResetCounter::ResetCounterJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::FixCounters').ping_ok
    end
  end
end
