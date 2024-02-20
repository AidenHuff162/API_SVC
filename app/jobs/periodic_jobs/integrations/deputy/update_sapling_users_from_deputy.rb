module PeriodicJobs::Integrations::Deputy
  class UpdateSaplingUsersFromDeputy
    include Sidekiq::Worker
    
    def perform
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'deputy' AND integration_instances.state = 1")
      companies.try(:each) do |company|
        ::HrisIntegrations::Deputy::UpdateSaplingUserFromDeputyJob.perform_async(company.id)
      end  
    end
  end
end
