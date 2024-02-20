module WorkstreamSerializer
  class WithOwnerConnections < Base
    attributes :tasks

    def tasks
      collection = TaskUserConnection.joins(task: :workstream)
        .where(user_id: instance_options[:owner_id] ,
               state: 'in_progress',
               is_offboarding_task: false,
               workstreams: {id: object.id}
               )
      ActiveModelSerializers::SerializableResource.new(collection , each_serializer: TaskUserConnectionSerializer::Light)
    end
  end
end

