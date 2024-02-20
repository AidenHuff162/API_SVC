module TaskUserConnectionSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :user_id, :task_id, :state, :due_date, :owner_id, :workstream_id, :name, :description,
               :attachments, :owner, :is_custom_due_date, :task_type, :user, :task_user, :workstream_name,
               :comment_count, :assign_on, :is_sub_tasks_in_progress, :inactive, :workspace_id, :owner_type, 
               :display_name_format
    belongs_to :task, serializer: TaskSerializer::Base
    belongs_to :workspace, serializer: WorkspaceSerializer::Basic

    def workstream_id
      object.task.workstream_id
    end

    def workstream_name
      object.task.workstream&.name
    end

    def name
      object.get_task_name
    end

    def description
      object.get_task_description
    end

    def attachments
      #TODO we've same objec into the task serilizer we can use that one and we should remove this one
      ActiveModelSerializers::SerializableResource.new(object.task.attachments, each_serializer: AttachmentSerializer)
    end

    def due_date
      if object.due_date
        object.due_date
      else
        object.user.start_date + object.task.deadline_in
      end
    end

    def task_user
      if @instance_options[:is_owner_view] == "true" || @instance_options[:is_owner_view] == true
        ActiveModelSerializers::SerializableResource.new(user_scope.includes(:profile_image, :team, :location, :manager, :company).find(object.user.id), serializer: UserSerializer::People)
      else
        ActiveModelSerializers::SerializableResource.new(user_scope.includes(:profile_image, :team, :location, :manager, :company).find(object.owner.id), serializer: UserSerializer::People)
      end
    end

    def owner
      ActiveModelSerializers::SerializableResource.new(user_scope.includes(:profile_image, :team, :location, :manager, :company).find(object.owner.id), serializer: UserSerializer::People) 
    end

    def user
      ActiveModelSerializers::SerializableResource.new(user_scope.includes(:profile_image, :team, :location, :manager, :company).find(object.user.id), serializer: UserSerializer::People) 
    end

    def task_type
      if object.jira_issue_id
        'jira'
      elsif object.service_now_id
        'service_now'
      else
        object.task.task_type
      end
    end

    def comment_count
      object.get_cached_comments_count
    end

    def assign_on
      object.in_progress? && object.before_due_date.present? && object.before_due_date > Date.today ? object.before_due_date : nil
    end

    def is_sub_tasks_in_progress
      object.is_sub_task_in_progress?
    end

    def inactive
      object.deleted_at.present?
    end

    def user_scope
      return User.with_deleted.all if @instance_options[:tasks_page] == "true" || @instance_options[:tasks_page] == true
      return User.all
    end

    def display_name_format
      object.user&.company&.display_name_format
    end
  end
end
