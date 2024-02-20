module PeriodicJobs::Integrations::Workday
  class UpdateSaplingUsersFromWorkday
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Workday::UpdateSaplingUsersFromWorkday').ping_start

      companies = Company.active_companies.joins(:integration_instances).where(integration_instances: { api_identifier: :workday, state: :active })
      companies.try(:each) do |company|
        ::HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.perform_async(company.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Workday::UpdateSaplingUsersFromWorkday').ping_ok
    end
  end
end
