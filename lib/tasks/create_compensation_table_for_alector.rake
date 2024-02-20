namespace :compensation_table_creation_for_alector do
	task :add_compensation_table_to_custom_tables, [:company_id] => :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		custom_table = company.custom_tables.create!(name: 'Compensation', table_type: CustomTable.table_types[:timeline], custom_table_property: CustomTable.custom_table_properties[:compensation], position: 2)

		custom_field_params = {
			locks: {all_locks: false, options_lock: false},
			collect_from: :admin,
			required: false,
			custom_table_id: custom_table.id,
			section: nil
    }


    salary1 = company.custom_fields.create!(custom_field_params.merge({name: 'Salary1', field_type: CustomField.field_types[:currency], position: 1}))
    salary1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    salary1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    hourly_wage1 = company.custom_fields.create!(custom_field_params.merge({name: 'Hourly wage1', field_type: CustomField.field_types[:currency], position: 2}))
    hourly_wage1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    hourly_wage1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    bonnus1 = company.custom_fields.create!(custom_field_params.merge({name: 'Bonus1', field_type: CustomField.field_types[:currency], position: 3}))
    bonnus1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    bonnus1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    option1 = company.custom_fields.create!(custom_field_params.merge({name: 'Option1', field_type: CustomField.field_types[:currency], position: 4}))
    option1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    option1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    starting_bonus = company.custom_fields.find_by(id: 2256)
    starting_bonus.update(custom_table_id: custom_table.id, position: 5, section: nil)

    relocation_expense = company.custom_fields.find_by(id: 2670)
    relocation_expense.update(custom_table_id: custom_table.id, position: 6, section: nil)
	end

	task :create_custom_table_user_sanpshots_for_compensation_table, [:company_id]=> :environment do |t, args|
		company = Company.find_by(id: args.company_id)

		if company.present?
			compensation_table = company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).first

			if compensation_table.present?
				effective_date = company.custom_fields.where(name: 'Effective Date', custom_table_id: compensation_table.id).first
				salary1 = company.custom_fields.where(name: 'Salary1', custom_table_id: compensation_table.id).first
				hourly_wage1 = company.custom_fields.where(name: 'Hourly wage1', custom_table_id: compensation_table.id).first
				bonnus1 = company.custom_fields.where(name: 'Bonus1', custom_table_id: compensation_table.id).first
				option1 = company.custom_fields.where(name: 'Option1', custom_table_id: compensation_table.id).first
			end

			salary = company.custom_fields.find_by(id: 1891)
			hourly_wage = company.custom_fields.find_by(id: 2027)
			bonus = company.custom_fields.find_by(id: 2026)
			option = company.custom_fields.find_by(id: 2028)
    	starting_bonus = company.custom_fields.find_by(id: 2256)
    	relocation_expense = company.custom_fields.find_by(id: 2670)

    	company.users.all.each do |user|
				salary_value = user.custom_field_values.find_by(custom_field_id: salary.id).try(:value_text)
				hourly_value = user.custom_field_values.find_by(custom_field_id: hourly_wage.id).try(:value_text)
				bonus_value = user.custom_field_values.find_by(custom_field_id: bonus.id).try(:value_text)
				option_value = user.custom_field_values.find_by(custom_field_id: option.id).try(:value_text)
				starting_bonus_value = user.custom_field_values.find_by(custom_field_id: starting_bonus.id).try(:value_text)
				relocation_expense_value = user.custom_field_values.find_by(custom_field_id: relocation_expense.id).try(:value_text)

				#creating custom table user snapshots along with custom snapshots
				if compensation_table.present? && (salary_value.present? || hourly_value.present? || bonus_value.present? || option_value.present? || starting_bonus_value.present? || relocation_expense_value.present?)
					ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: compensation_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
					if ctus.present?
						ctus.custom_snapshots.create!(custom_field_id: effective_date.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: effective_date.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
						ctus.custom_snapshots.create!(custom_field_id: starting_bonus.id, custom_field_value: starting_bonus_value)
						ctus.custom_snapshots.create!(custom_field_id: relocation_expense.id, custom_field_value: relocation_expense_value)

						currency_symbol = 'USD'

						ctus.custom_snapshots.create!(custom_field_id: salary1.id, custom_field_value: currency_symbol.to_s + "|" + salary_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, salary1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, salary1.name, salary_value.to_s.gsub(",",""), 'Currency Value', false, nil)

						ctus.custom_snapshots.create!(custom_field_id: hourly_wage1.id, custom_field_value: currency_symbol.to_s + "|" + hourly_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, hourly_wage1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, hourly_wage1.name, hourly_value.to_s.gsub(",",""), 'Currency Value', false, nil)

						ctus.custom_snapshots.create!(custom_field_id: bonnus1.id, custom_field_value: currency_symbol.to_s + "|" + bonus_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, bonnus1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, bonnus1.name, bonus_value.to_s.gsub(",",""), 'Currency Value', false, nil)

						ctus.custom_snapshots.create!(custom_field_id: option1.id, custom_field_value: currency_symbol.to_s + "|" + option_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, option1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, option1.name, option_value.to_s.gsub(",",""), 'Currency Value', false, nil)
					end
				end
			end

		end
	end

end

