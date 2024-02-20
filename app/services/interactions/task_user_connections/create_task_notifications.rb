module Interactions
  module TaskUserConnections
    module CreateTaskNotifications
      def create_task_notifications(user, task_ids, tasks, due_dates_from, company)
        send_slack_notifications(user, task_ids, tasks, due_dates_from) if is_slack_enabled?(company)
        create_tasks_in_asana(user.id) if is_asana_enabled?(company, user)
        create_tasks_in_jira(user.id, company)

        tucs_ids = TaskUserConnection.un_processed_service_now_tasks(user.id, get_hashed_tasks[:task_ids]) rescue nil
        return unless is_service_now_job_enabled?(company, tucs_ids)

        Productivity::ServiceNow::CreateTaskOnServiceNowJob.perform_async(user.id, company.id, tucs_ids)
      end

      private

      def send_slack_notifications(user, task_ids, tasks, due_dates_from)
        SlackService::SendTaskNotification.new(user, task_ids, tasks, due_dates_from).perform
      end

      def create_tasks_in_asana(user_id)
        CreateTasksOnAsanaJob.perform_async(user_id)
      end

      def create_tasks_in_jira(user_id, company)
        tucs = TaskUserConnection.un_processed_jira_tasks(user_id, get_hashed_tasks[:task_ids]) rescue nil
        CreateTaskOnJiraJob.perform_async(user_id, tucs) if is_jira_enabled?(company, tucs)
      end
      def is_slack_enabled?(company)
        integration_exists?(company, 'slack')
      end
    
      def is_asana_enabled?(company, user)
        integration_exists?(company, 'asana') && ['incomplete', 'departed'].exclude?(user.current_stage)
      end
    
      def is_jira_enabled?(company, tucs)
        tucs.present? && company.is_jira_enabled
      end
    
      def is_service_now_job_enabled?(company, tucs_ids)
        tucs_ids.present? && company.is_service_now_enabled?
      end

      def integration_exists?(company, api_name)
        company.integrations.find_by(api_name: api_name).present?
      end
    end
  end
end
