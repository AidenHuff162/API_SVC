module CustomFieldSerializer
  class HomeInfoPageWithValue < ActiveModel::Serializer
    attributes :id, :section, :position, :name, :help_text, :default_value, :field_type, :required, :collect_from, :custom_field_value, :custom_field_options, :sub_custom_fields, :is_sensitive_field

    def custom_field_value
      begin
        if instance_options[:user_id]
          value = object.get_custom_field_values_by_user(instance_options[:user_id], instance_options[:approval_profile_page])
          if value.class == Hash
            value['sub_custom_fields'].present? ? nil : value
          else
            ActiveModelSerializers::SerializableResource.new(value, serializer: CustomFieldValuesSerializer::Base, indentification_edit: instance_options[:indentification_edit], custom_field: object) if value.present?
          end
        end
      rescue Exception =>  e
        ' '
      end
    end

    def custom_field_options
      if CustomField::FIELD_TYPE_WITH_OPTION.include?(object.field_type)
        if object.name == 'Google Groups'
          google_cf ||= CustomFieldValue.find_by(custom_field_id: object.id, user_id: instance_options[:user_id])
          if google_cf && google_cf.checkbox_values.present?
            object.active_custom_field_options.where(id: google_cf.checkbox_values) 
          end
        else
          object.active_custom_field_options 
        end
      end
    end

    def sub_custom_fields
      begin
        if instance_options[:user_id] && object.sub_custom_fields
          if instance_options[:approval_profile_page].present? && CustomSectionApproval.is_custom_field_in_requested(object.id, instance_options[:user_id]) > 0
            value = CustomSectionApproval.get_custom_field_in_requested(object.id, instance_options[:user_id])
            return value.first['sub_custom_fields']
          else
            ActiveModelSerializers::SerializableResource.new(object.sub_custom_fields, each_serializer: SubCustomFieldSerializer::HomePage, user_id: instance_options[:user_id])
          end
        end
      rescue Exception => e
        ' '
      end
    end
  end
end
