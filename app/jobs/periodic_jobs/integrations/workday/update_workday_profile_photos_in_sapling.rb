module PeriodicJobs::Integrations::Workday
  class UpdateWorkdayProfilePhotosInSapling
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Workday::UpdateWorkdayProfilePhotosInSapling').ping_start

      companies = Company.active_companies.joins(:integration_instances).where(integration_instances: {api_identifier: :workday, state: :active})
      companies.try(:each) do |company|
        ::HrisIntegrations::Workday::UpdateWorkdayProfilePhotosInSapling.perform_later(company.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Workday::UpdateWorkdayProfilePhotosInSapling').ping_ok
    end
  end
end
