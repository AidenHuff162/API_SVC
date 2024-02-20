module UserSerializer
  class AutoComplete < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :full_name, :preferred_name, :picture, :preferred_full_name, :title, :location_name
  end
end
