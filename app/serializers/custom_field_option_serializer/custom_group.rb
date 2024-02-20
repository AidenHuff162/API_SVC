module CustomFieldOptionSerializer
  class CustomGroup < ActiveModel::Serializer
    attributes :id, :option, :description, :people_count, :user_ids, :inactive_count, :active
    has_one :owner, serializer: UserSerializer::Basic

    def inactive_count
      if object && (defined? object.users)
        return object.unscoped_users.where(state: "inactive").count
      else
        0
      end
    end

    def people_count
      if object && (defined? object.users)
        object.users.where(state: "active").count
      else
        0
      end
    end

    def user_ids
      object.users.where(state: "active").pluck(:id) if object && (defined? object.users)
    end
  end
end
