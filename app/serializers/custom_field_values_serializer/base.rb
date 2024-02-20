module CustomFieldValuesSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :value_text, :custom_field_option_id, :user_id, :custom_field_id, :sub_custom_field_id, :checkbox_values,
               :indentification_field, :coworker_id
    has_one :coworker, serializer: UserSerializer::Basic

    def value_text
      begin
        if instance_options[:custom_field] && instance_options[:custom_field].present? && ['social_security_number', 'social_insurance_number'].include?(instance_options[:custom_field].field_type) && !(instance_options[:indentification_edit].try(:present?))
          if object.value_text && object.value_text[0] != 'X'
            number = object.value_text.split('-')
            object.value_text = "#{number[0]}-#{number[1]}-#{number[2]}"
            object.value_text
          else
            object.value_text
          end
        else
          object.safe_encoded_value_text
        end
      rescue Exception => e
        ' '
      end
    end

    def indentification_field
      if instance_options[:custom_field] && ['social_security_number', 'social_insurance_number'].include?(instance_options[:custom_field].field_type)
          object.value_text
      else
        ' '
      end
    end
  end
end
