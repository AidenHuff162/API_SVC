module PeriodicJobs::Gsuite
  class UpdateGoogleGroups
    include Sidekiq::Worker
    
    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Gsuite::UpdateGoogleGroups').ping_start
      Gsuite::UpdateGoogleGroupsJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Gsuite::UpdateGoogleGroups').ping_ok
    end
  end
end
