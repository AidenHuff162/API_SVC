module PeriodicJobs::Integrations::Peakon
  class UpdateSaplingUsersFromPeakon
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Peakon::UpdateSaplingUsersFromPeakon').ping_start

      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'peakon' AND integration_instances.state = ?", IntegrationInstance.states[:active])
      companies.try(:each) do |company| 
        PerformanceIntegrations::Peakon::UpdateSaplingUserFromPeakonJob.perform_async(company.id)
      end
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Peakon::UpdateSaplingUsersFromPeakon').ping_ok
    end
  end
end