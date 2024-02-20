module WorkstreamSerializer
  class ForReports < Basic
    attribute :tasks

    def tasks
      all_tasks = @instance_options[:with_deleted_workstream_tasks] ? object.tasks.with_deleted : object.tasks
      ActiveModelSerializers::SerializableResource.new(all_tasks, each_serializer: TaskSerializer::ForReports)
    end
  end
end
