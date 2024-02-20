module PeriodicJobs::CustomTable
  class ManageCtusForDeadlockUsers
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageCtusForDeadlockUsers').ping_start
      ::CustomTables::SnapshotManagementDeadlockUsers.new.perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageCtusForDeadlockUsers').ping_ok
    end
  end
end