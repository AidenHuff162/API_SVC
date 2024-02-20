module PeriodicJobs::Integrations::SmartRecruiters
  class ImportPendingHiresFromSmartRecruiters
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::SmartRecruiters::ImportPendingHiresFromSmartRecruiters').ping_start
      
      Company.joins(:integration_instances).where(:integration_instances => {api_identifier: "smart_recruiters", state: :active}).try(:each) do |company|
        ::ImportPendingHiresFromSmartRecruitersJob.perform_later(company.id)
      end
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::SmartRecruiters::ImportPendingHiresFromSmartRecruiters').ping_ok
    end
  end
end