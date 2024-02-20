module PeriodicJobs::Users
  class RemoveExpiredGhostUsers
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::RemoveExpiredGhostUsers').ping_start
      ::Users::RemoveExpiredGhostUsersJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::RemoveExpiredGhostUsers').ping_ok
    end
  end
end
