module SaplingApiService
  class ProfileSetup
    attr_reader :company

    DEFAULT_FIELDS = [ 'first name', 'last name', 'preferred name', 'job title', 'job tier', 'manager', 'location',
      'department', 'start date', 'termination date', 'status', 'last day worked', 'company email', 'personal email',
      'profile photo', 'buddy', 'termination type', 'eligible for rehire', 'about', 'linkedin', 'twitter', 'github'
    ]

    def initialize(company)
      @company = company
    end

    def fetch_meta_data
      (prepare_preference_fields_meta_data + prepare_custom_fields_meta_date).to_json
    end

    private

    def prepare_field_meta_data_hash(profile_field, is_preference_field = false)
      meta_data = { id: profile_field[:api_field_id], name: profile_field[:name].titleize }

      section = nil
      field_type = nil
      if is_preference_field
        section = profile_field[:section].present? ? profile_field[:section] : profile_field[:custom_table_property]
        field_type = profile_field[:field_type]
      else
        section = profile_field&.custom_section&.section || profile_field&.custom_table&.name
        field_type = profile_field.field_type
      end

      return meta_data.merge({ section: section.try(:titleize), type: field_type.try(:titleize) })
    end

    def prepare_option_meta_data_hash(profile_field, profile_field_options = [])
      if profile_field_options.present?
        profile_field_options.pluck(:option).join("/")
      else
        case profile_field[:name]
        when 'Location'
          return company.locations.pluck(:name).join("/")
        when 'Department'
          return company.teams.pluck(:name).join("/")
        when 'Status'
          return 'active/inactive'
        end
      end
    end

    def prepare_sub_fields_meta_data_hash(profile_field)
      sub_fields = []
      profile_field.sub_custom_fields.try(:find_each) do |sub_custom_field|
        sub_fields.push({
          id: sub_custom_field.name.parameterize.underscore,
          name: sub_custom_field.name.titleize,
          type: sub_custom_field.field_type.titleize
        })
      end
      sub_fields
    end

    def prepare_preference_fields_meta_data
      profile_fields = []
      preferences = company.prefrences['default_fields'].select { |default_field| DEFAULT_FIELDS.include? default_field['name'].downcase }

      preferences.each do |preference|
        meta_data_hash = prepare_field_meta_data_hash(preference.symbolize_keys, true)

        if meta_data_hash[:type].downcase == CustomField.field_types.key(CustomField.field_types[:mcq])
          meta_data_hash[:options] = prepare_option_meta_data_hash(meta_data_hash)
        end

        profile_fields.push(meta_data_hash)
      end

      profile_fields
    end

    def prepare_custom_fields_meta_date
      profile_fields = []
      custom_fields = company.custom_fields

      custom_fields.try(:find_each) do |custom_field|
        meta_data_hash = prepare_field_meta_data_hash(custom_field)

        if meta_data_hash[:type].downcase == custom_field_type(:mcq)
          meta_data_hash[:options] = prepare_option_meta_data_hash(meta_data_hash, custom_field.custom_field_options)
        elsif [custom_field_type(:address), custom_field_type(:currency), custom_field_type(:phone)].include? meta_data_hash[:type].downcase
          meta_data_hash[:sub_fields] = prepare_sub_fields_meta_data_hash(custom_field)
        end

        profile_fields.push(meta_data_hash)
      end

      profile_fields
    end

    def custom_field_type(field_type_identifier)
      CustomField.field_types.key(CustomField.field_types[field_type_identifier])
    end
  end
end
