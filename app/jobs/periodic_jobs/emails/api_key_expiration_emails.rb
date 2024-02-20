module PeriodicJobs::Emails
  class ApiKeyExpirationEmails
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::ApiKeyExpirationEmails').ping_start
      ::ApiKeyExpirationEmailsJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::ApiKeyExpirationEmails').ping_ok
    end
  end
end
