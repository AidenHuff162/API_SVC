module PeriodicJobs::Integrations::Okta
  class SyncOktaEmployees
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Okta::SyncOktaEmployees').ping_start

      ::IntegrationInstance.where(api_identifier: 'okta', state: :active).try(:find_each) do |integration|
          ::Okta::SyncOktaEmployeesJob.perform_async(integration.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Okta::SyncOktaEmployees').ping_ok
    end
  end
end
