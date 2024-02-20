module WorkstreamSerializer
  class WithSortedTasks < Base
    attributes :user, :tasks
    has_many :tasks, serializer: TaskSerializer::WithConnections

    def user
      if @instance_options[:user_id]
        ActiveModelSerializers::SerializableResource.new(serializer: TaskSerializer::WithConnections, user_id: @instance_options[:user_id])
      end
    end

    def tasks
      workstream_tasks = object.tasks
      order = nil
      if @instance_options[:sort_type] == 'assignee_a_z'
        order = 'asc'
      elsif @instance_options[:sort_type] == 'assignee_z_a'
        order = 'desc'
      end
      if order != nil
        workstream_tasks = workstream_tasks.select("tasks.*, CASE WHEN tasks.task_type = '0'
                THEN task_users.preferred_full_name
                WHEN tasks.task_type = '1'
                  THEN 'hire'
                WHEN tasks.task_type = '2'
                  THEN 'manager'
                WHEN tasks.task_type = '3'
                  THEN 'buddy'
                WHEN tasks.task_type = '4'
                  THEN 'jira'
                WHEN tasks.task_type = '5'
                  THEN workspaces.name
                WHEN tasks.task_type = '6'
                  THEN custom_fields.name
                WHEN tasks.task_type = '7'
                  THEN 'service_now'
                END AS calculated").joins("
                LEFT OUTER JOIN users AS task_users ON task_users.id = tasks.owner_id
                LEFT OUTER JOIN workspaces ON tasks.workspace_id = workspaces.id
                LEFT OUTER JOIN custom_fields ON tasks.custom_field_id = custom_fields.id").reorder("calculated #{order}")
      elsif @instance_options[:sort_type] == 'latest_due_date'
        workstream_tasks = workstream_tasks.reorder("tasks.deadline_in desc")
      elsif @instance_options[:sort_type] == 'recent_due_date'
        workstream_tasks = workstream_tasks.reorder("tasks.deadline_in asc")
      end
      workstream_tasks
    end
  end
end
