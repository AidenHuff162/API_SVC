module WorkstreamSerializer
  class WithTasks < Basic
    attribute :tasks

    def tasks
      tasks = []
      all_tasks = @instance_options[:with_deleted_workstream_tasks] ? object.tasks.with_deleted : object.tasks
      if @instance_options[:exclude_by_user_id]
        tasks = all_tasks.where("NOT EXISTS(SELECT * FROM task_user_connections WHERE task_user_connections.task_id = tasks.id AND task_user_connections.user_id = ?)", @instance_options[:exclude_by_user_id])

      elsif @instance_options[:exclude_by_owner_id]
        tasks = all_tasks.where("NOT EXISTS(SELECT * FROM task_user_connections WHERE task_user_connections.task_id = tasks.id AND task_user_connections.owner_id = ?)", @instance_options[:exclude_by_owner_id])

      else
        if @instance_options[:task_owner_id]
          tasks = all_tasks.where(owner_id: @instance_options[:task_owner_id])
        else
          tasks = all_tasks
        end
      end

      ActiveModelSerializers::SerializableResource.new(tasks, each_serializer: TaskSerializer::Basic)
    end
  end
end
