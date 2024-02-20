module UserSerializer
  class ManagerFilter < ActiveModel::Serializer
    attributes :id, :preferred_full_name, :first_name, :last_name, :preferred_name
  end
end
