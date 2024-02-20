module PeriodicJobs::Integrations
  class SendEmployeesToBswift
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::SendEmployeesToBswift').ping_start

      IntegrationInstance.where(api_identifier: :bswift, state: :active).pluck(:company_id).each do |company_id|
        ::Integrations::SendEmployeesToBswiftJob.perform_async(company_id)
      end
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::SendEmployeesToBswift').ping_ok
    end
  end
end
