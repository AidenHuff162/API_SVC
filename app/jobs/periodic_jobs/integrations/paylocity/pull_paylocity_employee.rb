module PeriodicJobs::Integrations::Paylocity
  class PullPaylocityEmployee
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Paylocity::PullPaylocityEmployee').ping_start
    
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'paylocity' AND integration_instances.state = ?", IntegrationInstance.states[:active])
      companies.try(:each) do |company| 
        ::HrisIntegrations::Paylocity::UpdateSaplingUserFromPaylocityJob.perform_async(company.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Paylocity::PullPaylocityEmployee').ping_ok
    end
  end
end