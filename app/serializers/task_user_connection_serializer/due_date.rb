module TaskUserConnectionSerializer
  class DueDate < ActiveModel::Serializer
    attributes :name, :total_tasks, :outstanding_tasks_count, :completed_tasks_count,
               :overdue_tasks_count, :due_date, :task_type

    def name
      object.due_date
    end

    def total_tasks
      if @instance_options[:user_id]
        TaskUserConnection.joins(:task)
                          .joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                          .where(due_date: object.due_date, user_id: @instance_options[:user_id])
                          .count
      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:task)
                          .joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(due_date: object.due_date, owner_id: @instance_options[:owner_id])
                          .where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def outstanding_tasks_count
      if @instance_options[:user_id]
        TaskUserConnection.joins(:task)
                          .joins("INNER JOIN users ON users.id = task_user_connections.owner_id ")
                          .where(due_date: object.due_date, user_id: @instance_options[:user_id], state: 'in_progress')
                          .count
      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:task)
                          .joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(due_date: object.due_date, owner_id: @instance_options[:owner_id], state: 'in_progress')
                          .where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def completed_tasks_count
      if @instance_options[:user_id]
        TaskUserConnection.joins(:task)
                          .joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                          .where(due_date: object.due_date, user_id: @instance_options[:user_id], state: 'completed')
                          .count
      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:task)
                          .joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(due_date: object.due_date, owner_id: @instance_options[:owner_id], state: 'completed')
                          .where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def overdue_tasks_count
      if @instance_options[:user_id]
        count = TaskUserConnection.joins(:task)
                                  .joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                                  .where(due_date: object.due_date, user_id: @instance_options[:user_id], state: 'in_progress')
                                  .where('due_date < ?', Date.today)
                                  .count
      elsif @instance_options[:owner_id]
        count = TaskUserConnection.joins(:task)
                                  .joins(:user)
                                  .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                                  .where(due_date: object.due_date, owner_id: @instance_options[:owner_id], state: 'in_progress')
                                  .where('due_date < ?', Date.today)
                                  .where.not(tasks: {task_type: '4'})
                                  .count
      else
        0
      end
    end

    def task_type
      object.task.task_type
    end
  end
end
