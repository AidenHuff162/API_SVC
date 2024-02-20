class CreateTasksOnAsanaJob
  include Sidekiq::Worker
  sidekiq_options :queue => :asana_integration, :retry => true, :backtrace => true

  def perform(user_id)
    user = User.find_by(id: user_id)
    company = user.company rescue nil
    return unless user.present? && company.present? && company.integration_instances.find_by(api_identifier: "asana", state: :active).present?
    AsanaService::CreateTask.new(user).perform if user.task_user_connections.where(send_to_asana: true, user_id: user.id).count > 0
  end

end
