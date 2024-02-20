module PeriodicJobs::Integrations::Bamboo
  class UpdateSaplingUsersFromBamboo
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Bamboo::UpdateSaplingUsersFromBamboo').ping_start
    
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'bamboo_hr' AND integration_instances.state = 1 AND companies.account_state = 'active'")
      companies.try(:each) { |company| ::HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob.perform_later(company.id) }

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Bamboo::UpdateSaplingUsersFromBamboo').ping_ok
    end
  end
end