module PeriodicJobs::Pto
  class AutoCompletePtoRequest
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::AutoCompletePtoRequest').ping_start
      ::TimeOff::AutoCompletePtoRequestJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::AutoCompletePtoRequest').ping_ok
    end
  end
end
