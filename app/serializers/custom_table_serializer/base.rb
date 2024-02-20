module CustomTableSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :name, :position
  end
end
