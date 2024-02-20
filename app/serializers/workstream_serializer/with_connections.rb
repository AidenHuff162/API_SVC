module WorkstreamSerializer
  class WithConnections < Base
    attributes :user
    has_many :tasks, serializer: TaskSerializer::WithConnections

    def user
      if @instance_options[:user_id]
        ActiveModelSerializers::SerializableResource.new(serializer: TaskSerializer::WithConnections, user_id: @instance_options[:user_id])
      end
    end
  end
end

