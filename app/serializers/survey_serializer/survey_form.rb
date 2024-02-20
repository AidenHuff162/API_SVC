module SurveySerializer
  class SurveyForm < Base
    attributes :task_user_connection_id, :task_user, :task_user_connection_state

    def task_user_connection_id
      scope[:task_user_connection_id]
    end

    def task_user_connection_state
      scope[:task_user_connection_state]
    end

    def task_user
      ActiveModelSerializers::SerializableResource.new(TaskUserConnection.find(scope[:task_user_connection_id]).user, serializer: UserSerializer::Basic) if scope[:task_user_connection_id].present?
    end

  end
end
