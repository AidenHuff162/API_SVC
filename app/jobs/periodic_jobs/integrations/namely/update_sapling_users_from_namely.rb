module PeriodicJobs::Integrations::Namely
  class UpdateSaplingUsersFromNamely
    include Sidekiq::Worker
    
    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Namely::UpdateSaplingUsersFromNamely').ping_start

      companies = Company.joins(:integration_instances).where("integration_instances.api_identifier = 'namely' AND integration_instances.state = 1")
      companies.try(:each) do |company|
        ::HrisIntegrations::Namely::UpdateSaplingUserFromNamelyJob.perform_async(company.id)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Namely::UpdateSaplingUsersFromNamely').ping_ok   
    end
  end
end
