module UserSerializer
  class PeopleManager < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name
  end
end
