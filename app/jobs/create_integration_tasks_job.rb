class CreateIntegrationTasksJob < ApplicationJob
  queue_as :default

  def perform(user_id, tuc_ids, task_ids)
    user = User.find(user_id)
    company = user.company
    tasks = Task.where(id: task_ids)
    send_slack_notification(company, user, tuc_ids, tasks)
    create_asana_tasks(company, user)
    create_jira_tasks(company, user.id, task_ids)
    create_tasks_on_service(company, user.id, task_ids)
  end

  private

  def send_slack_notification(company, user, tuc_ids, tasks)
    return unless company.integrations.find_by(api_name: 'slack_notification')

    SlackService::SendTaskNotification.new(user, tuc_ids, tasks, nil).perform
  end

  def create_asana_tasks(company, user)
    return unless asana_integration?(company, user)

    CreateTasksOnAsanaJob.perform_async(user.id)
  end

  def create_jira_tasks(company, user_id, task_ids)
    task_user_connections = TaskUserConnection.un_processed_jira_tasks(user_id, task_ids) rescue nil
    return unless task_user_connections.present? && company.is_jira_enabled

    CreateTaskOnJiraJob.perform_async(user_id, task_user_connections)
  end

  def create_tasks_on_service(company, user_id, task_ids)
    tuc_ids = TaskUserConnection.un_processed_service_now_tasks(user_id, task_ids) rescue nil
    return unless tuc_ids.present? && company.is_service_now_enabled?

    Productivity::ServiceNow::CreateTaskOnServiceNowJob.perform_async(user_id, company.id, tuc_ids)
  end

  def asana_integration?(company, user)
    company.integration_instances.find_by(api_identifier: 'asana', state: :active).present? && %w[incomplete departed].exclude?(user.current_stage)
  end
end
