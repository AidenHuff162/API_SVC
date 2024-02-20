module PeriodicJobs::CustomSection
  class ManageExpiredApprovalTypeCsApproval
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomSection::ManageExpiredApprovalTypeCsApproval').ping_start
      ::CustomSections::ManageExpiredCustomSectionApprovalJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomSection::ManageExpiredApprovalTypeCsApproval').ping_ok
    end
  end
end
