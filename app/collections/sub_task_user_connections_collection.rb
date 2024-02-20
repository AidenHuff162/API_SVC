class SubTaskUserConnectionsCollection < BaseCollection
private

  def relation
    @relation ||= SubTaskUserConnection.all
  end

  def ensure_filters
    task_user_connection_filter
  end

  def task_user_connection_filter
    filter { |relation| relation.where(task_user_connection_id: params[:task_user_connection_id]) } if params[:task_user_connection_id]
  end
end
