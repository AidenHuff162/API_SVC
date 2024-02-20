module PeriodicJobs::Users
  class SetUserCurrentStage
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::SetUserCurrentStage').ping_start
      ::Users::InitializeUserCurrentStageJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::SetUserCurrentStage').ping_ok
    end
  end
end
