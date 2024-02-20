module PeriodicJobs::Integrations::TeamSpirit
  class SendCsvFilesToTeamSpirit
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::TeamSpirit::SendTeamSpiritFile').ping_start
      ::IntegrationInstance.where(api_identifier: 'team_spirit').try(:find_each) do |integration|
        day = integration.integration_credentials.find_by(name: "Day").value
        company = integration.company
        today = Time.now.in_time_zone(company.time_zone)

        if day == today.wday.to_s && today.hour == 8
          ::TeamSpirit::UpdateSaplingUserToTeamSpiritJob.perform_async(integration.id)
        end
      end
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::TeamSpirit::SendTeamSpiritFile').ping_ok
    end
  end
end
