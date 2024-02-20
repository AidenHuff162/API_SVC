module PeriodicJobs::Integrations::Onelogin
  class UpdateSaplingUsersFromOnelogin
    include Sidekiq::Worker
    
    def perform  
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Onelogin::UpdateSaplingUsersFromOnelogin').ping_start

      Company.where(deleted_at: nil).try(:find_each) do |company|
        ::SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob.perform_async(company.id) if company.authentication_type == 'one_login'
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Onelogin::UpdateSaplingUsersFromOnelogin').ping_ok

    end
  end
end