module PeriodicJobs::Integrations::FifteenFive
  class UpdateSaplingUsersFromFifteenFive
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::FifteenFive::UpdateSaplingUsersFromFifteenFive').ping_start

      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'fifteen_five' AND integration_instances.state = ?", IntegrationInstance.states[:active])
      companies.try(:each) do |company| 
        PerformanceIntegrations::FifteenFive::UpdateSaplingUserFromFifteenFiveJob.perform_async(company.id)
      end
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::FifteenFive::UpdateSaplingUsersFromFifteenFive').ping_ok
    end
  end
end