module FieldHistorySerializer
  class Index < ActiveModel::Serializer
    attributes :id, :field_name, :new_value, :field_changer, :created_at, :field_type, :object_creation_time, :obj_created_at, :field_auditable_type, :field_auditable_id
    def field_changer
      if object.integration.present? and object.field_changer.blank?
        {name: object.integration.api_name.titleize}

      elsif object.integration_instance.present? and object.field_changer.blank?
        {name: object.integration_instance.api_identifier.titleize}

      elsif object.field_changer.present?
        {name: object.field_changer.display_name, title: object.field_changer.title}

      else
        {}
      end
    end

    def obj_created_at
      object.created_at.utc.in_time_zone(scope[:company].time_zone)
    end

    def object_creation_time
      object.created_at.utc.in_time_zone(scope[:company].time_zone).strftime("%I:%M %p")
    end

    def new_value
      if object.custom_field.present? and ['social_security_number', 'social_insurance_number'].include?(object.custom_field.field_type)
        unless instance_options[:identification_edit].present?
          if object.new_value.present?
            number = object.new_value.split('-')
            number[0] = number[0].gsub(/.(?=.{0,}$)/,'X') if number[0]
            number[1] = number[1].gsub(/.(?=.{0,}$)/,'X') if number[1]
            object.new_value = "#{number[0]}-#{number[1]}-#{number[2]}"
          end
        end
        object.new_value
      elsif object.custom_field.present? && object.custom_field.field_type.eql?('address') && 
            object.custom_field.sub_custom_fields.present?
        begin
          eval(object.new_value).values.join(', ')
        rescue Exception => e
          object.new_value
        end
      else
        object.new_value
      end
    end

  end
end
