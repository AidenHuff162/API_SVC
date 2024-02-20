module PeriodicJobs::Pto
  class AssignUnassignedPtoPolicies
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::AssignUnassignedPtoPolicies').ping_start
      ::TimeOff::ActivateUnassignedPolicy.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::AssignUnassignedPtoPolicies').ping_ok
    end
  end
end
