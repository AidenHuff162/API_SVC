module PeriodicJobs::Integrations::Xero
  class PullEmployeesFromXeroJob
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Xero::PullEmployeesFromXeroJob').ping_start

      Company.joins(:integration_instances).where("integration_instances.api_identifier = 'xero' AND integration_instances.state = 1").try(:find_each) do |company|
        ::HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob.perform_async(company.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Xero::PullEmployeesFromXeroJob').ping_ok
    end
  end
end
