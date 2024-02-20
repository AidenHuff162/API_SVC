module UserSerializer
  class WithOpenWorkspaceTaskCounts < Base
    attributes :id, :title, :location, :open_tasks_count, :picture, :name,
    :manager, :display_name

    def name
      object.full_name
    end

    def location
      object.location.try(:name)
    end

    def open_tasks_count
      if @instance_options[:workspace_id]
        object.task_user_connections.where(workspace_id: @instance_options[:workspace_id], owner_type: TaskUserConnection.owner_types[:workspace]).count
      else
        0
      end
    end

    def manager
      if object.manager
        ActiveModelSerializers::SerializableResource.new(object.manager, serializer: UserSerializer::HistoryUser)
      end
    end
  end
end
