module UserRoleSerializer
  class CustomAlert < ActiveModel::Serializer
    attributes :id, :name, :role_type
  end
end
