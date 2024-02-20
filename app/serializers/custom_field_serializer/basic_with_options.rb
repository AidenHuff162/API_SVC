module CustomFieldSerializer
  class BasicWithOptions < ActiveModel::Serializer
    attributes :id, :name, :field_type, :position, :custom_field_options, :sub_custom_fields, :is_sensitive_field, :help_text, :default_value

    def custom_field_options
      ActiveModelSerializers::SerializableResource.new(object.active_custom_field_options, each_serializer: CustomFieldOptionSerializer::WithOnlyOptions) if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def sub_custom_fields
      if instance_options[:user_id] && object.sub_custom_fields
        ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::HomePage, user: User.find(instance_options[:user_id]))
      elsif object.sub_custom_fields && instance_options[:omit_user]
        ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::HomePage)
      end
    end
  end
end
