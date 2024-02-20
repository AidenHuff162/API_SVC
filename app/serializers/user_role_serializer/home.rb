module UserRoleSerializer
  class Home < ActiveModel::Serializer
    attributes :id, :position, :is_default, :users_count, :role_type, :name, :permissions

    def users_count
      if object.role_type == "super_admin" && object.name != 'Ghost Admin'
        object.users.where(super_user: false).where.not(current_stage: User.current_stages[:departed]).count
      else
        object.users.where.not(current_stage: User.current_stages[:departed]).count
      end
    end
  end
end
