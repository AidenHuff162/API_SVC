module PeriodicJobs::Integrations::Namely
  class ReceiveEmployeesProfileImageFromNamely
    include Sidekiq::Worker
    
    def perform        
      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Namely::ReceiveEmployeesProfileImageFromNamely').ping_start
    
      Company.joins(:integrations).where(companies: {deleted_at: nil}, integrations: {api_name: :namely}).try(:find_each) do |company|
        ::UpdateSaplingDepartmentsAndLocationsFromNamelyJob.perform_later(nil, company)
        ::ReceiveUpdatedEmployeePictureFromNamelyJob.perform_later(company)
      end

      HealthCheck::HealthCheckService.new('PeriodicJobs::Integrations::Namely::ReceiveEmployeesProfileImageFromNamely').ping_ok
    end
  end
end