module PeriodicJobs::Documents
  class HandleBuggySignedDocumentsValidator
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Documents::HandleBuggySignedDocumentsValidator').ping_start
      ::Documents::ValidateBuggySignedDocumentsJob.perform_async
      HealthCheck::HealthCheckService.new('PeriodicJobs::Documents::HandleBuggySignedDocumentsValidator').ping_ok
    end
  end
end
