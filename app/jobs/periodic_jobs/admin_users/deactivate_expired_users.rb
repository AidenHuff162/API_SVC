module PeriodicJobs::AdminUsers
  class DeactivateExpiredUsers
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::AdminUsers::DeactivateExpiredUsers').ping_start
      ::AdminUsers::DeactivateExpiredUsersJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::AdminUsers::DeactivateExpiredUsers').ping_ok
    end
  end
end
