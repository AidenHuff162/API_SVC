module PeriodicJobs
  class AddMonthlyActiveUsers
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::AddMonthlyActiveUsers').ping_start
      ::MauJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::AddMonthlyActiveUsers').ping_ok
    end
  end
end
