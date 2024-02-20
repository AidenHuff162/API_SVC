module CustomTableSerializer
  class BulkOnboarding < ActiveModel::Serializer
    attributes :id, :name, :custom_table_property, :position
    has_many :custom_fields, serializer: CustomFieldSerializer::WithOptions

  end
end
