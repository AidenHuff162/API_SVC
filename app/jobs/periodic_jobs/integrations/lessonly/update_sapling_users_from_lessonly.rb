module PeriodicJobs::Integrations::Lessonly
  class UpdateSaplingUsersFromLessonly
    include Sidekiq::Worker
    
    def perform        
      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'lessonly' AND integration_instances.state = 1")
      companies.try(:each) do |company| 
        ::LearningDevelopmentIntegrations::Lessonly::UpdateSaplingUserFromLessonlyJob.perform_async(company.id)
      end  
    end
  end
end