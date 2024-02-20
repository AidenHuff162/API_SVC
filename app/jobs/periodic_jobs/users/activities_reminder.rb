module PeriodicJobs::Users
  class ActivitiesReminder
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::ActivitiesReminder').ping_start
      ::Users::ActivitiesReminderJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Users::ActivitiesReminder').ping_ok
    end
  end
end
