namespace :update_activities do
  desc 'Update task user connections if thier due date is changed'
  task update_tasks: :environment do
    TaskUserConnection.where(state: "in_progress").find_each do |tuc|
      if tuc.user_id && tuc.task_id && tuc.task.deadline_in && (tuc.user.start_date + tuc.task.deadline_in.days) != tuc.due_date
        tuc.is_custom_due_date = true
        tuc.save!
      end
    end
  end

  desc 'Updates user outcome connections if their deadline in is changed'
  task update_outcomes: :environment do
    UserOutcomeConnection.where(state: "in_progress").find_each do |uoc|
      if uoc.outcome_id && uoc.deadline_in != uoc.outcome.deadline_in
        uoc.is_custom_deadline_in = true
        uoc.save!
      end
    end
  end

  desc 'Updates all the activities'
  task all: [:update_tasks, :update_outcomes]
end
