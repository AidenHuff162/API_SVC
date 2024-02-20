class AssignDependentTasksJob < ApplicationJob
  queue_as :default

  def perform(id)
    tucs = TaskUserConnection.where('? = ANY(dependent_tuc)', id)
    draft_tucs = draft_tasks(tucs)
    return if tucs.blank? || draft_tucs.blank?

    user = tucs[0].user
    task_ids = draft_tucs.pluck(:task_id)
    tuc_ids = draft_tucs.pluck(:id)
    Interactions::Activities::Assign.new(user, task_ids, nil, false).perform
    CreateIntegrationTasksJob.perform_now(user.id, tuc_ids, task_ids)
  end

  private

  def draft_tasks(tucs)
    draft_tasks = []
    tucs.each do |t|
      t.completed_dependent_task_count += 1
      if t.completed_dependent_task_count.eql?(t.dependent_tuc.length)
        t.update(state: :in_progress)
        draft_tasks.push(t)
      end
      t.save!
    end
    draft_tasks
  end
end
