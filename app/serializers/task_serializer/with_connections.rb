module TaskSerializer
  class WithConnections < Simple
    attributes :task_user_connection, :draft_task_user_connection, :task_user_connection_user, :searchReassign, :workspace_id, :task_user_connection_workspace, :custom_field_id, :task_coworker, :survey_id, :task_schedule_options
    has_one :user, serializer: UserSerializer::Short
    belongs_to :workstream, serializer: WorkstreamSerializer::Base
    belongs_to :custom_field, serializer: CustomFieldSerializer::Basic
    has_one :workspace, serializer: WorkspaceSerializer::Onboard

    def task_user_connection
      return nil if @instance_options[:rehire] == "true"
      if instance_options[:user_id]
        object.task_user_connections.includes(:user, :owner).find_by(user_id: instance_options[:user_id])
      else
        object.task_user_connections.includes(:user, :owner).find_by(owner_id: instance_options[:owner_id])
      end
    end

    def draft_task_user_connection
      return nil if @instance_options[:rehire] == "true"
      if instance_options[:user_id]
        TaskUserConnection.joins(:task).draft_connections.where(task_id: object.id).includes(:user, :owner).find_by(user_id: instance_options[:user_id])
      else
        TaskUserConnection.joins(:task).draft_connections.where(task_id: object.id).includes(:user, :owner).find_by(owner_id: instance_options[:owner_id])
      end
    end

    def task_user_connection_user
      UserSerializer::Short.new(task_user_connection.user) if task_user_connection
    end

    def task_user_connection_workspace
      connection = task_user_connection
      if connection && connection.workspace.present?
        ActiveModelSerializers::SerializableResource.new(connection.workspace, serializer: WorkspaceSerializer::Onboard)
      end
    end

    def owner
      connection = task_user_connection

      if connection
        connection.owner
      else
        object.task_type == 'owner' ? object.owner : nil
      end
    end

    def user
      task_user_connection.try(:user)
    end

    def searchReassign
      false
    end

    def task_coworker
      if !object.custom_field.nil?
        custom_field_value = object.custom_field.custom_field_values.where(user_id: @instance_options[:user_id].to_i).first
        if !custom_field_value.nil?
          custom_field_value.coworker
        end
      end
    end
  end
end
