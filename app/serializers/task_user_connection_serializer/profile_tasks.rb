module TaskUserConnectionSerializer
  class ProfileTasks < ActiveModel::Serializer
    attributes :id, :user_id, :task_id, :state, :due_date, :owner_id, :workstream_id, :name,
               :task_type, :user, :task_user, :workstream_name,
               :comment_count, :assign_on, :is_sub_tasks_in_progress, :inactive, :workspace_id, :owner_type, :owner_display_name, :owner_user_deleted, :owner,
               :completed_at, :display_name_format, :survey_id

    belongs_to :workspace, serializer: WorkspaceSerializer::Simple

    def workstream_id
      object.task.workstream_id
    end

    def workstream_name
      object.task.workstream.name
    end

    def owner_user_deleted
      user = object.owner || object.user
      if user
        user.deleted?
      end
    end

    def name
      object.get_task_name
    end

    def due_date
      if object.due_date
        object.due_date
      else
        object.user.start_date + object.task.deadline_in
      end
    end

    def task_user
      if (@instance_options[:is_owner_view] == "true" || @instance_options[:is_owner_view] == true) && object.user.present?
        ActiveModelSerializers::SerializableResource.new(object.user, serializer: UserSerializer::HomeTask)
      elsif object.owner.present?
        ActiveModelSerializers::SerializableResource.new(object.owner, serializer: UserSerializer::HomeTask)
      end
    end

    def user
      return unless object.user.present?

      ActiveModelSerializers::SerializableResource.new(object.user, serializer: UserSerializer::HomeTask)
    end

    def owner
      return unless object.owner.present?
      
      ActiveModelSerializers::SerializableResource.new(object.owner, serializer: UserSerializer::HomeTask)
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

    def owner_display_name
      object.owner.company.global_display_name(object.owner, object.owner.company.display_name_format)
    end

    def completed_at
      object.completed_at
    end

    def display_name_format
      object.user.company.display_name_format rescue 0
    end

    def survey_id
      object.task.try(:survey_id)
    end

  end
end
