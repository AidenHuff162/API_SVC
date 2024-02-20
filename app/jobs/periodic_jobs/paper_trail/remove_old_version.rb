module PeriodicJobs::PaperTrail
  class RemoveOldVersion
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::PaperTrail::RemoveOldVersion').ping_start
      ::PaperTrail::RemoveOldVersionJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::PaperTrail::RemoveOldVersion').ping_ok
    end
  end
end
