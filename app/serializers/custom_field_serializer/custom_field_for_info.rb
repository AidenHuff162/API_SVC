module CustomFieldSerializer
  class CustomFieldForInfo < ActiveModel::Serializer
    attributes :id, :name, :position, :field_type

  end
end
