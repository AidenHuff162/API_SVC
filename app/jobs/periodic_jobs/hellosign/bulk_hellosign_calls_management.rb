module PeriodicJobs::Hellosign
  class BulkHellosignCallsManagement
    include Sidekiq::Worker
    
    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Hellosign::BulkHellosignCallsManagement').ping_start
      HandleBulkHellosignCallJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Hellosign::BulkHellosignCallsManagement').ping_ok
    end
  end
end
