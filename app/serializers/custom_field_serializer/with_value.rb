module CustomFieldSerializer
  class WithValue < Base
    attributes :custom_field_value, :custom_field_options, :locks, :integration_group, :sub_custom_fields
    
    def custom_field_value
      begin
        if instance_options[:user_id]
          value = object.get_custom_field_values_by_user(instance_options[:user_id], instance_options[:approval_profile_page])
          if value.class == Hash
            value['sub_custom_fields'].present? ? nil : value
          else
            ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::Base, indentification_edit: instance_options[:indentification_edit], current_user: instance_options[:current_user], custom_field: object) if value
          end
        end
      rescue Exception =>  e
        ' '
      end
    end

    def custom_field_options
      object.active_custom_field_options if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
    end

    def sub_custom_fields
      begin
        if object.sub_custom_fields
          if instance_options[:approval_profile_page].present? && CustomSectionApproval.is_custom_field_in_requested(object.id, instance_options[:user_id]) > 0
            value = CustomSectionApproval.get_custom_field_in_requested(object.id, instance_options[:user_id])
            return value.first['sub_custom_fields']
          else
            ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::Basic, user_id: instance_options[:user_id])
          end
        end
      rescue Exception => e
        ' '
      end
    end

  end
end
