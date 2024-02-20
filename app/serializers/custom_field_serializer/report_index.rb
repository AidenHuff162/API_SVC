module CustomFieldSerializer
  class ReportIndex < ActiveModel::Serializer
    attributes :section, :name, :custom_field_options, :custom_table_id, :field_type, :id
    has_many :sub_custom_fields, serializer: SubCustomFieldSerializer::Basic
    
    def custom_field_options
      object.active_custom_field_options if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end
  end
end
