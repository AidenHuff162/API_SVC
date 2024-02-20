module PeriodicJobs::TaskUserConnections
  class CompleteTaskFromServicenow
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CompleteTaskFromServicenow').ping_start
      ::TaskUserConnections::CompleteTaskFromServicenowJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::CompleteTaskFromServicenow').ping_ok
    end
  end
end
