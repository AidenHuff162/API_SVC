module PeriodicJobs::CustomTable
  class ManageCustomTableUserSnapshots
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageCustomTableUserSnapshots').ping_start
      ::CustomTables::SnapshotManagement.new.manage_timeline_snapshots_overnight()
      HealthCheck::HealthCheckService.new('PeriodicJobs::CustomTable::ManageCustomTableUserSnapshots').ping_ok
    end
  end
end
