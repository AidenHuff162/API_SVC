module PeriodicJobs::Integrations::Slack
  class SendIntegrationsApiErrorToSlack
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Slack::SendIntegrationsApiErrorToSlack').ping_start
      ::IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Slack::SendIntegrationsApiErrorToSlack').ping_ok
    end
  end
end