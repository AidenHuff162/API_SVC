module UserSerializer
  class WithTasks < Base
    attributes :id, :name, :total_tasks, :outstanding_tasks_count, :completed_tasks_count,
               :overdue_tasks_count

    def name
      object.full_name
    end

    def total_tasks
      if @instance_options[:user_id]
        TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                          .where(owner_id: object.id, user_id: @instance_options[:user_id])
                          .count

      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(owner_id: @instance_options[:owner_id], user_id: object.id)
                          .joins(:task).where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def outstanding_tasks_count
      if @instance_options[:user_id]
        TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                          .where(owner_id: object.id, user_id: @instance_options[:user_id], state: 'in_progress')
                          .count

      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(owner_id: @instance_options[:owner_id], user_id: object.id, state: 'in_progress')
                          .joins(:task).where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def completed_tasks_count
      if @instance_options[:user_id]
        TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                          .where(owner_id: object.id, user_id: @instance_options[:user_id], state: 'completed')
                          .count

      elsif @instance_options[:owner_id]
        TaskUserConnection.joins(:user)
                          .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                          .where(owner_id: @instance_options[:owner_id], user_id: object.id, state: 'completed')
                          .joins(:task).where.not(tasks: {task_type: '4'})
                          .count
      else
        0
      end
    end

    def overdue_tasks_count
      if @instance_options[:user_id]
        count = TaskUserConnection.joins("INNER JOIN users ON users.id = task_user_connections.owner_id")
                                  .where(owner_id: object.id, user_id: @instance_options[:user_id], state: 'in_progress')
                                  .where('due_date < ?', Date.today)
                                  .count

      elsif @instance_options[:owner_id]
        count = TaskUserConnection.joins(:user)
                                  .where("(users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
                                  .where(owner_id: @instance_options[:owner_id], user_id: object.id, state: 'in_progress')
                                  .where('due_date < ?', Date.today)
                                  .joins(:task).where.not(tasks: {task_type: '4'})
                                  .count
      else
        0
      end
    end

  end
end
