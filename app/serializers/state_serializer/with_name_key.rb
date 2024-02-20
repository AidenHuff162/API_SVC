module StateSerializer
  class WithNameKey < ActiveModel::Serializer
    attributes :id, :name, :key
  end
end
