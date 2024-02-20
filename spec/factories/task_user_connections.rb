FactoryGirl.define do
  factory :task_user_connection do
    task
    user
    due_date { user.start_date + task.deadline_in }
    from_due_date { user.start_date + task.deadline_in }
    owner { user }
  end

  factory :scheduled_task_user_connection, parent: :task_user_connection do
    task
    user
    due_date { user.start_date + task.deadline_in }
    from_due_date { user.start_date + task.deadline_in }
    before_due_date { user.start_date + task.deadline_in + task.before_deadline_in }
    schedule_days_gap { task.before_deadline_in }
    association :owner, factory: :user
  end

  factory :overdue_task_user_connection, parent: :task_user_connection do
    due_date 5.days.ago
  end
end
