module SubCustomFieldSerializer
  class HomePage < ActiveModel::Serializer
    attributes :id, :name, :field_type, :help_text, :custom_field_value

    def custom_field_value
      begin
        if instance_options[:user_id] && instance_options[:user_id].present?
          value = object.get_sub_custom_field_values_by_user(instance_options[:user_id])
          ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::ForSubCustomFields) if value.present?
        end
      rescue Exception => e
        ' '
      end
    end
  end
end
