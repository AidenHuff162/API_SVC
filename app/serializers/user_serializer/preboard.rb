module UserSerializer
  class Preboard <  ActiveModel::Serializer
    attributes :first_name, :last_name, :preferred_name, :picture
  end
end
