module TaskSerializer
  class Base < Simple
    type :task

    attributes :task_schedule_options, :user_assigned_count, :survey_id
    belongs_to :workspace, serializer: WorkspaceSerializer::Basic
    belongs_to :custom_field, serializer: CustomFieldSerializer::Basic

    def user_assigned_count
      TaskUserConnection.where(task_id: object.id).pluck(:user_id).uniq.count
    end
  end
end
