module PeriodicJobs::Integrations::Gusto
  class UpdateSaplingUsersFromGusto
    include Sidekiq::Worker
    
    def perform        
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'gusto' AND integration_instances.state = 1")
      companies.try(:each) do |company| 
        ::HrisIntegrations::Gusto::UpdateSaplingUserFromGustoJob.perform_async(company.id)
      end  
    end
  end
end