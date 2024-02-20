module LocationSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name
  end
end
