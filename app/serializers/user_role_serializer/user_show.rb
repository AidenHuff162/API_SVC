module UserRoleSerializer
  class UserShow < ActiveModel::Serializer
    attributes :id, :users_count, :role_type, :name, :users

    def users
      return [] if @instance_options[:permission] != 'view_and_edit'
      users = object.company.users.where(user_role_id: object.id)
      ActiveModelSerializers::SerializableResource.new(users, each_serializer: UserSerializer::Profile)
    end


    def users_count
      object.users.count
    end
  end
end
