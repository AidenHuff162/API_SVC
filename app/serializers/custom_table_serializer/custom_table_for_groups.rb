module CustomTableSerializer
  class CustomTableForGroups < ActiveModel::Serializer
    attributes :id, :name
  end
end
