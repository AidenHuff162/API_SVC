module SubTaskManagement
  extend ActiveSupport::Concern

  def create_sub_task_user_connections(task_user_connection)
    sub_tasks = task_user_connection.task&.sub_tasks
    sub_tasks.try(:each) do |sub_task|
      task_user_connection.sub_task_user_connections.create!(sub_task_id: sub_task.id, state: sub_task.state)
    end
  end

  def update_sub_task_user_connections_state(task_user_connection, state)
    sub_task_user_connections = task_user_connection.sub_task_user_connections
    sub_task_user_connections.update_all(state: state) if sub_task_user_connections.present?
  end
end
