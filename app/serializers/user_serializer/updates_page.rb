module UserSerializer
  class UpdatesPage < ActiveModel::Serializer
    attributes :id, :picture, :preferred_name, :first_name, :last_name
  end
end
