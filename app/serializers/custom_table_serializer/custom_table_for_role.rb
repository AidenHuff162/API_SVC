module CustomTableSerializer
  class CustomTableForRole < ActiveModel::Serializer
    attributes :id, :name, :position, :table_type, :custom_table_property
    has_many :custom_fields, serializer: CustomFieldSerializer::BasicWithOptions
  end
end
