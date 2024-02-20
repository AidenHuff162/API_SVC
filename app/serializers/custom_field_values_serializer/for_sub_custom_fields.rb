module CustomFieldValuesSerializer
  class ForSubCustomFields < ActiveModel::Serializer
    attributes :id, :value_text

    def value_text
      begin
        if object.custom_field && object.custom_field.field_type == 'social_security_number' && !(instance_options[:indentification_edit].present?)
          if object.value_text && object.value_text[0] != 'X'
            number = object.value_text.split('-')
            number[0] = number[0].gsub(/.(?=.{0,}$)/,'X') if number[0]
            number[1] = number[1].gsub(/.(?=.{0,}$)/,'X') if number[1]
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
  end
end
