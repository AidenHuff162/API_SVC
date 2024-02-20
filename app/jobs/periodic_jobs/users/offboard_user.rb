module PeriodicJobs::Users
  class OffboardUser
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::OffboardUser').ping_start
      ::Users::OffboardUserJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::OffboardUser').ping_ok
    end
  end
end
