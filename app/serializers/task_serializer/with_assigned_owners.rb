module TaskSerializer
	class WithAssignedOwners < Base
		attributes :user_task_connection_owner_object, :user_task_connection_id, :custom_field_id

		def user_task_connection_owner_object
			object.task_user_connections.find_by_user_id(instance_options[:user_id]).owner rescue nil
		end

		def user_task_connection_id
			object.task_user_connections.find_by_user_id(instance_options[:user_id]).id	rescue nil
		end

	end
end
