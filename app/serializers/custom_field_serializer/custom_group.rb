module CustomFieldSerializer
  class CustomGroup < ActiveModel::Serializer
    attributes :id, :name, :custom_field_options, :custom_table_id, :is_integration_group_type, :field_type, :collect_from, :locks, :custom_section_id, :section, :api_field_id

    def custom_field_options
      ActiveModelSerializers::SerializableResource.new(object.custom_field_options, each_serializer: CustomFieldOptionSerializer::CustomGroup) if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def is_integration_group_type
      !(object.no_integration? || object.custom_group?) 
    end

  end
end
