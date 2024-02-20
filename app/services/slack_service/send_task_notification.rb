module SlackService
  class SendTaskNotification
    attr_reader :user, :company, :tasks, :task_user_connection_ids, :due_dates_from

    def initialize(user = nil, task_user_connection_ids = nil, tasks = nil, due_dates_from = nil)
      return unless user.present? || task_user_connection_ids.present? || tasks.nil?
      @user = user
      @company = user.company
      return unless company.present?
      @task_user_connection_ids = task_user_connection_ids
      @tasks = tasks
      @due_dates_from = due_dates_from
    end

    def perform
      send_slack_notification
    end

    private

    def send_slack_notification
      immediate_tasks = tasks.select { |task| task['time_line'] == 'immediately' }
      delayed_tasks = tasks.select { |task| task['time_line'] == 'later' }

      if immediate_tasks.length > 0
        message_content = {
            type: 'assign_task',
            tasks: immediate_tasks,
            due_dates_from: due_dates_from
        }
        SlackIntegrationJob.perform_async('Task_Assign', { user_id: user.id, current_company_id: company.id, message_content: message_content })
      end

      if delayed_tasks.length > 0
        delayed_tasks.each do |task|
          notify_on = TaskUserConnection.find_by(id: task_user_connection_ids, task_id: task['id']).try(:before_due_date)&.to_time&.in_time_zone(company.time_zone)
          message_content = {
              type: 'assign_task',
              tasks: [task.as_json],
              due_dates_from: due_dates_from
          }
          job_id = SlackIntegrationJob.perform_at(notify_on, 'Task_Assign', { user_id: user.id, current_company_id: company.id, message_content: message_content }) if notify_on
          tuc = TaskUserConnection.find_by(id: task_user_connection_ids, task_id: task['id']) if job_id
          tuc.update(job_id:job_id) if tuc
        end
      end
    end
  end
end
