namespace :add_working_pattern_preference_field_in_companies do
  task add_working_pattern: :environment do
    puts '---- Adding working pattern field started ----'

    Company.all.find_each do |company|
      prefrences = company.prefrences
      next if prefrences['default_fields'].count { |f| f['id'] == 'wp' }.positive?

      position = if company.is_using_custom_table?
                   prefrences['default_fields'].map { |f| f['position'] if f['custom_table_property'] == 'employment_status' }.compact.max
                 else
                   prefrences['default_fields'].map { |f| f['position'] }.compact.max
                 end

      working_pattern_field = {
        id: 'wp',
        name: 'Working Pattern',
        api_field_id: 'working_pattern',
        section: 'personal_info',
        position: position + 1,
        isDefault: true,
        editable: true,
        enabled: true,
        field_type: 'mcq',
        collect_from: 'admin',
        can_be_collected: false,
        visibility: true,
        is_editable: false,
        custom_table_property: '',
        profile_setup: 'profile_fields',
        deletable: false,
        is_sensitive_field: false,
        ats_mapping_section: nil,
        ats_integration_group: nil,
        ats_mapping_field_type: nil,
        ats_mapping_key: nil
      }.stringify_keys

      if company.is_using_custom_table?
        working_pattern_field.merge!({ 'custom_table_property' => 'employment_status', 'profile_setup' => 'custom_table', 'section' => '',
                                       'custom_section_id' => '' })
      end

      prefrences['default_fields'].push(working_pattern_field)
      company.update_column(:prefrences, prefrences)
    end

    puts '---- Adding working pattern field finished ----'
  end
end
