module CustomFieldSerializer
  class RequestedInformationPage < ActiveModel::Serializer
    attributes :id, :position, :name, :help_text, :default_value, :field_type, :custom_field_value, :custom_field_options, :sub_custom_fields

    def custom_field_value
      if instance_options[:user_id]
        value = object.get_custom_field_values_by_user(instance_options[:user_id])
        ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::Base, indentification_edit: instance_options[:indentification_edit], current_user: instance_options[:current_user], custom_field: object) if value
      end
    end

    def custom_field_options
      object.active_custom_field_options if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def sub_custom_fields
      if (object.phone? || object.address? || object.currency?) && object.sub_custom_fields
        ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::Basic, user_id: instance_options[:user_id])
      end
    end
  end
end
