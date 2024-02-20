module PeriodicJobs::Integrations::Lattice
  class UpdateSaplingUsersFromLattice
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Lattice::UpdateSaplingUsersFromLattice').ping_start

      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'lattice' AND integration_instances.state = ?", IntegrationInstance.states[:active])
      companies.try(:each) do |company| 
        PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob.perform_async(company.id)
      end
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::lattice::UpdateSaplingUsersFromLattice').ping_ok
    end
  end
end