module CustomSnapshotSerializer
  class ForInfo < ActiveModel::Serializer
    attributes :id, :custom_field_id, :preference_field_id, :custom_field_value, :position, :value_text, :coworker, :is_employment_status_field, :hide, :name

    def position
      if object.custom_field_id.present?
        object.custom_field.position
      elsif object.preference_field_id.present?
        company = @instance_options[:company]
        position = company.prefrences['default_fields'].find_all{ |field| field['id'] == object.preference_field_id }[0]['position']
      end
    end

    def value_text
      company = @instance_options[:company]

      if object.custom_field_id.present?
        if object.custom_field.mcq? || object.custom_field.employment_status?
          object.custom_field.custom_field_options.find_by(id: object.custom_field_value).try(:option)
        elsif object.custom_field.coworker?
          company.users.find_by(id: object.custom_field_value).try(:display_name)
        elsif object.custom_field.number? && object.custom_field_value.present?
          object.custom_field_value = ActiveSupport::NumberHelper.number_to_delimited(object.custom_field_value)
        elsif object.custom_field.phone? && object.custom_field_value.present?
          fetch_phone_field_value_text()
        else
          object.custom_field_value
        end
      elsif object.preference_field_id.present?
        if ['man', 'bdy'].include? object.preference_field_id
          company.users.find_by(id: object.custom_field_value).try(:display_name)
        elsif object.preference_field_id == 'dpt'
          company.teams.find_by(id: object.custom_field_value).try(:name)
        elsif object.preference_field_id == 'loc'
          company.locations.find_by(id: object.custom_field_value).try(:name)
        elsif ['st', 'tt', 'efr'].include? object.preference_field_id
          object.custom_field_value.try(:titleize)
        else
          object.custom_field_value
        end
      end
    end

    def coworker
      company = @instance_options[:company]
      if object.preference_field_id.present? || object.custom_field&.coworker?
        return company.users.find_by(id: object.custom_field_value)
      end
    end

    def fetch_phone_field_value_text
      if object.custom_field.phone?
        value_text = ''
        value_collection = object.custom_field_value.split('|')
        country = ISO3166::Country.find_country_by_alpha3(value_collection[0].present? ? value_collection[0] : '' ) rescue ''
        country_code = country.country_code rescue ''
        area_code = value_collection[1].present? ? value_collection[1] : '' rescue ''
        number = value_collection[2].present? ? value_collection[2] : '' rescue ''
        value_text = '+'.concat(country_code + '-' + area_code + '-' + number) rescue ''
        return value_text
      end
    end

    def is_employment_status_field
      if object.custom_field_id.present?
        if object.custom_field.employment_status?
          true
        end
      end
    end

    def hide
      object.custom_field.try(:is_sensitive_field)
    end

    def name
      if object.custom_field_id.present?
        object.custom_field.name
      elsif object.preference_field_id.present?
        company = @instance_options[:company]
        name = company.prefrences['default_fields'].find_all{ |field| field['id'] == object.preference_field_id }[0]['name']
      end
    end

  end
end
