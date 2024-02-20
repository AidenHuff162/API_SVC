module PeriodicJobs::Activities
  class ScheduleTasks
    include Sidekiq::Worker

    def perform
      HealthCheck::HealthCheckService.new('PeriodicJobs::Activities::ScheduleTasks').ping_start
      ::Activities::ScheduleTasksJob.perform_later
      HealthCheck::HealthCheckService.new('PeriodicJobs::Activities::ScheduleTasks').ping_ok
    end
  end
end
