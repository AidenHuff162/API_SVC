namespace :create_custom_tables_with_columns_for_company do
  task update_existing_companies: :environment do
    Company.all.each do |company|
      params = {
         company_id: company.id,
         locks: {all_locks: true, options_lock: false},
         required: true,
         collect_from: :admin
      }
      compensation_table_params = {
        company_id: company.id,
        locks: {all_locks: false, options_lock: false},
        required: true,
        collect_from: :admin
      }

      employment_status = company.custom_tables.create(name: "Employment Status",  is_deletable: false, custom_table_property: 3, position: 2)
      role_information = company.custom_tables.create(name: "Role Information",  is_deletable: false, custom_table_property: 2, position: 0)
      compensation = company.custom_tables.create(name: "Compensation", is_deletable: false, custom_table_property: 1,position: 1)

      employment_status_field = company.custom_fields.where("name ILIKE ?", 'Employment Status')
      if employment_status_field.present?
        employment_status_field.update(custom_table_id: employment_status.id, position: 1)
      end

      notes_field = company.custom_fields.where("name ILIKE ?", 'Notes')
      if notes_field.present? && notes_field.custom_table_id == nil
        notes_field.update(custom_table_id: employment_status.id, position: 7)
      else
        employment_status.custom_fields.create!(params.merge({name: "Notes", field_type: 1, position: 7}))
      end
      role_information.custom_fields.create!(params.merge({name: "Notes", field_type: 1, position: 6}))
      compensation.custom_fields.create!(compensation_table_params.merge({name: "Notes", field_type: 1, position: 5}))

      effective_field = company.custom_fields.where("name ILIKE ?", 'Effective Date')
      if effective_field.present? && effective_field.custom_table_id == nil
        effective_field.update(custom_table_id: employment_status.id, position: 0)
      else
        employment_status.custom_fields.create!(params.merge({name: "Effective Date", field_type: 6, position: 0}))
      end
      role_information.custom_fields.create!(params.merge({name: "Notes", field_type: 1, position: 6}))
      compensation.custom_fields.create!(compensation_table_params.merge({name: "Effective Date", field_type: 6, position: 0}))

      pay_rate_field = company.custom_fields.where("name ILIKE ?", 'Pay Rate')
      if pay_rate_field.present? && pay_rate_field.custom_table_id == nil
        pay_rate_field.update(custom_table_id: compensation.id,  position: 1)
      else
        compensation.custom_fields.create!(compensation_table_params.merge({name: "Pay Rate", field_type: 10, position: 1}))
      end

      pay_type_field = company.custom_fields.where("name ILIKE ?", 'Pay Type')
      if pay_type_field.present? && pay_type_field.custom_table_id == nil
        pay_type_field.update(custom_table_id: compensation.id,  position: 2)
      else
        compensation.custom_fields.create!(compensation_table_params.merge({name: "Pay Type", field_type: 4, position: 2}))
      end

      pay_schedule = company.custom_fields.where("name ILIKE ?", 'Pay Schedule')
      if pay_rate_field.present? && pay_rate_field.custom_table_id == nil
        pay_rate_field.update(custom_table_id: compensation.id, position: 3)
      else
        compensation.custom_fields.create!(compensation_table_params.merge({name: "Pay Schedule", field_type: 4, position: 3}))
      end

      change_reason_field = company.custom_fields.where("name ILIKE ?", 'Change Reason')
      if change_reason_field.present? && change_reason_field.custom_table_id == nil
        change_reason_field.update(custom_table_id: compensation.id, position: 4)
      else
        compensation.custom_fields.create!(compensation_table_params.merge({name: "Change Reason", field_type: 1, position: 4}))
      end

      company.prefrences['default_fields'].each do |field|
        if field['id'] == "st"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table'})
        elsif field['id'] == "efr"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table'})
        elsif field['id'] == "tt"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table'})
        elsif field['id'] == "ltw"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table'})
        elsif field['id'] == "td"
          field.merge!({"custom_table_property" => "employment_status", "profile_setup" => 'custom_table'})
        elsif field['id'] == "dpt"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table'})
        elsif field['id'] == "loc"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table'})
        elsif field['id'] == "jt"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table'})
        elsif field['id'] == "bdy"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table'})
        elsif field['id'] == "man"
          field.merge!({"custom_table_property" => "role_information", "profile_setup" => 'custom_table'})
        else
          field.merge({"profile_setup" => 'profile_fields'})
        end
      end
    end
  end
end
