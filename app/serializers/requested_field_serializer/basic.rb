module RequestedFieldSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :field_type, :custom_field_id, :custom_field_value, :preference_field_id
    
  end
end
