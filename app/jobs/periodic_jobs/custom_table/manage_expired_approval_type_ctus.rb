module PeriodicJobs::CustomTable
  class ManageExpiredApprovalTypeCtus
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageExpiredApprovalTypeCtus').ping_start
      ::CustomTables::ManageExpiredCustomTableUserSanpshotJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageExpiredApprovalTypeCtus').ping_ok
    end
  end
end
