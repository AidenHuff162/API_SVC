class DeleteDependentTasksJob < ApplicationJob
  queue_as :default

  def perform(id, workstream)
    return unless workstream.present?

    tasks = workstream.tasks.where('? = ANY(dependent_tasks)', id)
    tasks.each do |t|
      t.dependent_tasks.delete(id)
      t.save!
    end
  end
end
