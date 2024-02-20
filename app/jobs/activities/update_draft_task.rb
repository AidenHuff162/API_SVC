class Activities::UpdateDraftTask
  include Sidekiq::Worker
  sidekiq_options :queue => :default, :retry => false, :backtrace => true

  def perform(company_id, user_id, draft_tasks_params)
    begin
      company = Company.find_by_id(company_id)

      return unless company

      user = company.users.find_by_id(user_id)
      
      return unless user

      tucs = user.reload.task_user_connections.independent_connections.draft_connections
      tuc_ids = tucs.ids
      tucs.update(state: :in_progress)
      SlackService::SendTaskNotification.new(user, tuc_ids, draft_tasks_params).perform if company.integrations.find_by(api_name: 'slack_notification').present?
      CreateTasksOnAsanaJob.perform_async(user.id) if company.integration_instances.find_by(api_identifier: 'asana', state: :active).present?
      CreateTaskOnJiraJob.perform_async(user.id, tuc_ids) if tuc_ids.present? && company.is_jira_enabled
      Productivity::ServiceNow::CreateTaskOnServiceNowJob.perform_async(user.id, user.company.id, tuc_ids) if tuc_ids.present? && company.is_service_now_enabled?
      Interactions::Activities::Assign.new(user, tucs.pluck(:task_id), nil, true).perform if tucs.present?
    rescue Exception => e
      create_general_logging(company, 'Onboarding', { action: 'Assigning draft tasks to user', user_id: user.id, error_message: e.message })
    end
  end

  private

  def create_general_logging(company, action, data, type='Overall')
    LoggingService::GeneralLogging.new.create(company, action, data, type)
  end
end
