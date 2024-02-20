module StateSerializer
  class WithKey < ActiveModel::Serializer
    attributes :id, :map_value, :value

    def map_value
      object.name
    end

    def value
      object.key
    end
  end
end
