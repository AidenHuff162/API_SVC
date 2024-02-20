class DestroyTaskJob < ApplicationJob
  queue_as :destroy_task

  def perform(task_id)
    ActiveRecord::Base.transaction do
      task = Task.with_deleted.where(id: task_id).first
      if task.present?
        # task.task_user_connections.lock(true)
        task.destroy 
      end
    end
  end
end
