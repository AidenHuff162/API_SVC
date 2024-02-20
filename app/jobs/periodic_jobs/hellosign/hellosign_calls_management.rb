module PeriodicJobs::Hellosign
  class HellosignCallsManagement
    include Sidekiq::Worker
    
    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Hellosign::HellosignCallsManagement').ping_start
      HandleHellosignCallJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Hellosign::HellosignCallsManagement').ping_ok
    end
  end
end
