module TaskSerializer
  class Dashboard < ActiveModel::Serializer
    attributes :id, :name, :workstream_name, :task_owners_count, :users_count, :custom_field_id, :task_overdue_owners_count

    def workstream_name
      object.workstream.name
    end

    def task_owners_count
      Task
        .joins(:task_user_connections)
        .where(task_user_connections: {state: 'in_progress'}, id: object.id)
        .pluck("task_user_connections.owner_id")
        .uniq
        .count
    end

    def task_overdue_owners_count
      Task
        .joins(:task_user_connections)
        .where(task_user_connections: {state: 'in_progress'}, id: object.id)
        .where("task_user_connections.due_date < ? ", Date.today)
        .pluck("task_user_connections.owner_id")
        .uniq
        .count
    end

    def users_count
      Task
        .joins(:task_user_connections)
        .where(task_user_connections: {state: 'in_progress'}, id: object.id)
        .pluck("task_user_connections.user_id")
        .uniq
        .count
    end
  end
end
