module OffBoard
  class ReassignTemplateTasksJob < ApplicationJob
    queue_as :default
    def perform(data)
      return if !data
      data.each do |task_owner_id|
        task = Task.find_by(id: task_owner_id[0])
        next unless task
        if task_owner_id[2] == true
          task.destroy!
        else
          task.owner_id = task_owner_id[1]
          task.task_type = 'owner'
          task.save!
        end
      end
    end
  end
end
