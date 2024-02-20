module PeriodicJobs::Integrations::Asana
  class SyncTasksFromAsana
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Asana::SyncTasksFromAsana').ping_start
      ::Integrations::SyncTasksFromAsanaJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Asana::SyncTasksFromAsana').ping_ok
    end
  end
end
