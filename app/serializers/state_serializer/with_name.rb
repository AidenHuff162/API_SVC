module StateSerializer
  class WithName < ActiveModel::Serializer
    attributes :id, :map_value, :value

    def map_value
      object.key 
    end

    def value
      object.name
    end
  end
end
