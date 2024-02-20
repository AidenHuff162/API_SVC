module CustomFieldSerializer
  class PreboardingPageWithValue < ActiveModel::Serializer
    attributes :id, :section, :position, :name, :help_text, :default_value, :field_type, :required, :collect_from, :custom_field_value, :custom_field_options,
               :sub_custom_fields

    def custom_field_value
      if instance_options[:user_id].present?
        value = object.get_custom_field_values_by_user(instance_options[:user_id])
        ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::Base) if value
      end
    end

    def custom_field_options
      object.active_custom_field_options if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def sub_custom_fields
      if instance_options[:user_id] && object.sub_custom_fields.present?
        ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::PreboardingPage, user_id: instance_options[:user_id])
      end
    end
  end
end
