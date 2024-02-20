module Activities
  class ScheduleTasksJob < ApplicationJob

    def perform
      Interactions::Activities::ScheduleTasks.new.perform
    end

  end
end
