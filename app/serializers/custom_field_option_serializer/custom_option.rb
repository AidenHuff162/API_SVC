module CustomFieldOptionSerializer
  class CustomOption < ActiveModel::Serializer
    attributes :id, :option, :custom_field_id, :position
  end
end
