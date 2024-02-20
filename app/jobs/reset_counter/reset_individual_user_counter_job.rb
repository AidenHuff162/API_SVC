class ResetCounter::ResetIndividualUserCounterJob
  include Sidekiq::Worker
  sidekiq_options queue: :reset_user_counter, retry: false, backtrace: true

  def perform(company_id, user_id)
    return unless company_id.present? || user_id.present?

    begin
      company = Company.find_by_id(company_id)
      user = company.users.find_by_id(user_id)
      user.outstanding_tasks_count = user.task_user_connections.joins(:task).joins(:owner).where(state: :in_progress).count
      user.outstanding_owner_tasks_count = TaskUserConnection.joins(:user).joins(:task).where("task_user_connections.owner_id = ? AND task_user_connections.state = ? AND tasks.task_type != ? AND tasks.task_type != ? AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", user.id, 'in_progress', Task.task_types[:jira], Task.task_types[:service_now], Sapling::Application::ONBOARDING_DAYS_AGO).count
      user.incomplete_paperwork_count = User.user_incomplete_paperwork_requests_count(user_id)
      user.co_signer_paperwork_count = User.user_incomplete_co_signer_paperwork_requests_count(user_id)
      user.incomplete_upload_request_count = User.user_incomplete_upload_requests_count(user_id)      
      user.save
    rescue Exception => e
      create_general_logging(company, 'Reset User Counter', { user_id: user_id, error: e.message })
    end
  end

  private

  def create_general_logging(company, action, data, type = 'Overall')
    LoggingService::GeneralLogging.new.create(company, action, data, type)
  end
end
