module SubCustomFieldSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :field_type, :help_text, :custom_field_value

    def custom_field_value
      if instance_options[:user_id]
        value = object.get_sub_custom_field_values_by_user(instance_options[:user_id])
        ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::Base) if value
      end
    end
  end
end
