module PeriodicJobs::Integrations::Paylocity
  class PullCostCenterOptions
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Paylocity::PullCostCenterOptions').ping_start
    
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'paylocity' AND integration_instances.state = ?", IntegrationInstance.states[:active])
      companies.try(:each) do |company| 
        cost_centers = ['Cost Center 1', 'Cost Center 2', 'Cost Center 3']
        cost_centers.each do |const_center|
          HrisIntegrationsService::Paylocity::CostCenters.new(const_center.downcase.delete(' '), company).fetch    
        end
      end
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Paylocity::PullCostCenterOptions').ping_ok
    end
  end
end
