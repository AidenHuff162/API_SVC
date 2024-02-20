module PeriodicJobs::Integrations::LearnUpon
  class UpdateSaplingUsersFromLearnUpon
    include Sidekiq::Worker
    
    def perform        
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'learn_upon' AND integration_instances.state = 1")
      companies.try(:each) do |company| 
        ::LearningDevelopmentIntegrations::LearnUpon::UpdateSaplingUserFromLearnUponJob.perform_async(company.id)
      end  
    end
  end
end