module PeriodicJobs::Integrations::Kallidus
  class UpdateSaplingUsersFromKallidusLearn
    include Sidekiq::Worker
    
    def perform        
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'kallidus_learn' AND integration_instances.state = 1")
      companies.try(:each) do |company| 
        ::LearningDevelopmentIntegrations::Kallidus::UpdateSaplingUserFromKallidusJob.perform_async(company.id)
      end
    end
  end
end
