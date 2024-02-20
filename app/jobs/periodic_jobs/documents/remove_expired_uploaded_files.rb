module PeriodicJobs::Documents
  class RemoveExpiredUploadedFiles
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Documents::RemoveExpiredUploadedFiles').ping_start
      ::Documents::RemoveExpiredUploadedFile.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Documents::RemoveExpiredUploadedFiles').ping_ok
    end
  end
end
