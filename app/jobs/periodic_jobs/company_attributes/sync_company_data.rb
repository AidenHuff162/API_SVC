module PeriodicJobs::CompanyAttributes
  class SyncCompanyData
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::CompanyAttributes::SyncCompanyData').ping_start
      Company.find_each {|company| ::AccountPropertiesSyncJob.perform_async(company.id) }
      HealthCheck::HealthCheckService.new('PeriodicJobs::CompanyAttributes::SyncCompanyData').ping_ok
    end
  end
end
