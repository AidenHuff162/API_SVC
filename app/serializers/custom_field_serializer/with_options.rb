module CustomFieldSerializer
  class WithOptions < Base
    attributes :custom_field_options, :locks, :display_location, :sub_custom_fields, :ats_mapping_key,
    :ats_mapping_section, :ats_mapping_field_type, :workday_mapping_key, :is_group_type_field

    def custom_field_options
       ActiveModelSerializers::SerializableResource.new(object.active_custom_field_options, each_serializer: CustomFieldOptionSerializer::CustomOption) if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def sub_custom_fields
      if object.sub_custom_fields.present?
        ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::PreboardingPage)
      end
    end

    def is_group_type_field
      !object.no_integration?
    end

  end
end
