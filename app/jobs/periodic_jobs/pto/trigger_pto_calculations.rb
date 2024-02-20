module PeriodicJobs::Pto
  class TriggerPtoCalculations
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::TriggerPtoCalculations').ping_start
      
      companies_for_calculations = []
      companies_at_end = [] 
      Company.where(enabled_time_off: true).each do |company|
        companies_for_calculations << company.id if company.time.hour == 0
        companies_at_end << company.id if company.time.hour == 19
      end
      ::TimeOff::PtoCalculationsJob.perform_later(companies_for_calculations, companies_at_end)
      
      LoggingService::GeneralLogging.new.create(nil, 'PTO Calculations', { result: "Calculations at midnight for companies  #{companies_for_calculations}, 
        Accrual at end for companies  #{companies_at_end}, Server time #{Time.now}" }, 'PTO')
      
      HealthCheck::HealthCheckService.new('PeriodicJobs::Pto::TriggerPtoCalculations').ping_ok
    end
  end
end
