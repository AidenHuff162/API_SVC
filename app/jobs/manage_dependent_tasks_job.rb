class ManageDependentTasksJob < ApplicationJob
  queue_as :default

  def perform(id)
    tucs = TaskUserConnection.where('? = ANY(dependent_tuc)', id)
    draft_tucs = draft_tasks(tucs, id)
    return if tucs.blank? || draft_tucs.blank?

    user = tucs[0].user
    task_ids = draft_tucs.pluck(:task_id)
    tuc_ids = draft_tucs.pluck(:id)
    Interactions::Activities::Assign.new(user, task_ids, nil, false).perform
    CreateIntegrationTasksJob.perform_now(user.id, tuc_ids, task_ids)
  end

  private

  def draft_tasks(tucs, id)
    draft_tasks = []
    tucs.each do |t|
      if t.dependent_tuc.length.eql?(1)
        t.destroy!
      elsif t.dependent_tuc.length > 1
        t.dependent_tuc.delete(id)
        if t.completed_dependent_task_count.eql?(t.dependent_tuc.length)
          t.update(state: :in_progress)
          draft_tasks.push(t)
        end
        t.save!
      end
    end
  end
end
