module PeriodicJobs::Integrations::Adp
  class PullEmployeesFromAdpWorkforceNow
    include Sidekiq::Worker
    
    def perform       
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Adp::PullEmployeesFromAdpWorkforceNow').ping_start
    
      Company.where(deleted_at: nil).try(:find_each) do |company|
        if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| company.integration_types.include?(api_name) }.present? 
          ::ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(company.id)
        end
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Adp::PullEmployeesFromAdpWorkforceNow').ping_ok
    end
  end
end