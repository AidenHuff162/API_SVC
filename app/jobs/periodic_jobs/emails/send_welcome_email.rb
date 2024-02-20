module PeriodicJobs::Emails
  class SendWelcomeEmail
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::SendWelcomeEmail').ping_start
      ::Users::SendWelcomeEmailJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Emails::SendWelcomeEmail').ping_ok
    end
  end
end
