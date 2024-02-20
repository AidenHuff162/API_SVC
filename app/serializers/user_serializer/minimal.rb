module UserSerializer
  class Minimal < ActiveModel::Serializer
    attributes :id, :first_name, :last_name

  end
end
