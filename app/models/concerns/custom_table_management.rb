module CustomTableManagement
  extend ActiveSupport::Concern

  def create_default_custom_tables(company)
    custom_field_params = {
      company_id: company.id,
      locks: { all_locks: false, options_lock: false },
      required: false,
      collect_from: :admin
    }
    create_tables(company, custom_field_params) 
  end

  def create_tables(company, params)
    role_table = company.custom_tables.where(name: 'Role Information').first_or_create!(name: 'Role Information', custom_table_property: CustomTable.custom_table_properties[:role_information], is_deletable: false, position: 0)
    status_table = company.custom_tables.where(name: 'Employment Status').first_or_create!(name: 'Employment Status', custom_table_property: CustomTable.custom_table_properties[:employment_status], is_deletable: false, position: 2)
    compensation_table = company.custom_tables.where(name: 'Compensation').first_or_create(name: 'Compensation', custom_table_property: CustomTable.custom_table_properties[:compensation], is_deletable: false, position: 1)

    if status_table.present?
      company.custom_fields.where(name: 'Employment Status').first.update(custom_table_id: status_table.id, section: nil, custom_section_id: nil) 
      status_table.custom_fields.where(name: 'Notes').first_or_create!(params.merge({name: 'Notes', field_type: CustomField.field_types[:short_text], position: 3}))
    end

    if compensation_table.present?
      pay_rate = compensation_table.custom_fields.where(name: 'Pay Rate').first_or_create!(params.merge({name: 'Pay Rate', field_type: CustomField.field_types[:currency], position: 1}))
      if pay_rate
        pay_rate.sub_custom_fields.where(name: 'Currency Type').first_or_create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
        pay_rate.sub_custom_fields.where(name: 'Currency Value').first_or_create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value' )
      end

      compensation_table.custom_fields.where(name: 'Pay Type').first_or_create!(params.merge({ name: 'Pay Type', field_type: CustomField.field_types[:mcq], position: 2}))
      compensation_table.custom_fields.where(name: 'Pay Schedule').first_or_create!(params.merge({ name: 'Pay Schedule', field_type: CustomField.field_types[:mcq], position: 3 }))
      compensation_table.custom_fields.where(name: 'Change Reason').first_or_create!(params.merge({ name: 'Change Reason', field_type: CustomField.field_types[:long_text], position: 4 }))
      compensation_table.custom_fields.where(name: 'Notes').first_or_create!(params.merge({ name: 'Notes', field_type: CustomField.field_types[:short_text], position: 5 }))
    end
    if company && company.prefrences && company.prefrences['default_fields']
      company.prefrences['default_fields'].each do |field|
        if field['id'] == "st"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 2})
        elsif field['id'] == "efr"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 7})
        elsif field['id'] == "tt"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 6})
        elsif field['id'] == "ltw"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 5})
        elsif field['id'] == "td"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 4})
        elsif field['id'] == "wp"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 8})
        elsif field['id'] == "dpt"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 3})
        elsif field['id'] == "loc"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 2})
        elsif field['id'] == "jt"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 1})
        elsif field['id'] == "man"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table', "section" => "", "custom_section_id" => "", "position" => 4})
        else
          field.merge({"profile_setup" => 'profile_fields'})
        end
      end
      prefrences = company.prefrences
      company.update_columns(prefrences: prefrences)
    end
  end

  def create_custom_table_default_snapshots(custom_field)
    custom_table = custom_field.custom_table
    custom_table.custom_table_user_snapshots.try(:each) do |ctus|
      ctus.custom_snapshots.create!(custom_field_id: custom_field.id, custom_field_value: nil)
    end
  end

  def manage_default_timeline_table_column(custom_table, on_company_creation = false)
    effective_date = custom_table.custom_fields.where('name ILIKE ?', 'Effective Date').first
    params = { name: 'Effective Date', locks: { all_locks: true }, field_type: CustomField.field_types[:date], collect_from: :admin,
      custom_table_id: custom_table.id, company_id: custom_table.company_id }

    position = on_company_creation.present? ? 0 : custom_table.custom_fields.maximum('position')

    if effective_date.present?
      effective_date.update_columns(params.merge({ position: position }))
    else
      CustomField.create!(params.merge({ position: position }))
    end
  end
end

