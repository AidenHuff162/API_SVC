module PeriodicJobs::Users
  class CreateUserCalendarEvent
    include Sidekiq::Worker
  
    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::CreateUserCalendarEvent').ping_start
      ::Users::CreateUserCalendarEventJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::CreateUserCalendarEvent').ping_ok
    end
  end
end
