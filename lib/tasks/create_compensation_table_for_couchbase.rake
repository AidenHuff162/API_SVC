namespace :create_compensation_table_for_couchbase do
	task add_compensation_table_to_couchbase: :environment do
		company = Company.find_by(id: 84)
		custom_table = company.custom_tables.find_or_initialize_by(name: 'Compensation', table_type: CustomTable.table_types[:timeline], custom_table_property: CustomTable.custom_table_properties[:compensation], position: 2)
		custom_table.save

		custom_field_params = {
			locks: {all_locks: false, options_lock: false},
			collect_from: :admin,
			required: false,
			custom_table_id: custom_table.id,
			field_type: CustomField.field_types[:currency],
			section: nil
    }

    pay_freq = company.custom_fields.find_by(id: 4207)
    pay_freq.update(custom_table_id: custom_table.id, position: 1)

    pay_type = company.custom_fields.find_by(id: 4208)
    pay_type.update(custom_table_id: custom_table.id, position: 2)

    stock_option = company.custom_fields.find_by(id: 3733)
    stock_option.update(custom_table_id: custom_table.id, position: 8)


		base_rate1 = company.custom_fields.create(custom_field_params.merge({name: 'BaseRate1', position: 3 }))
		base_rate1.sub_custom_fields.create(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
		base_rate1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		salary1  = company.custom_fields.create(custom_field_params.merge({name: 'Salary1', position: 4 }))
		salary1.sub_custom_fields.create(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
		salary1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		annual_salary1  = company.custom_fields.create(custom_field_params.merge({name: 'Annual Salary1', position: 5 }))
		annual_salary1.sub_custom_fields.create(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
		annual_salary1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		bonus1  = company.custom_fields.create(custom_field_params.merge({name: 'Bonus1', position: 6 }))
		bonus1.sub_custom_fields.create(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
		bonus1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		commission1 = company.custom_fields.create(custom_field_params.merge({name: 'Commission1', position: 7 }))
		commission1.sub_custom_fields.create(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
		commission1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

	end

	task create_custom_snapshots_for_couchbase: :environment do
		company = Company.find_by(id: 84)
		#custom section fields
    base_rate = company.custom_fields.find_by(id: 4205)
    salary = company.custom_fields.find_by(id: 4206)
    annual_salary = company.custom_fields.find_by(id: 4340)
    bonus = company.custom_fields.find_by(id: 2951)
    commission = company.custom_fields.find_by(id: 2952)
    currency = company.custom_fields.find_by(id: 2953)

		#custom table fields
		custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation])

    pay_freq = company.custom_fields.find_by(id: 4207, custom_table_id: custom_table.id)
    pay_type = company.custom_fields.find_by(id: 4208, custom_table_id: custom_table.id)
    stock_option = company.custom_fields.find_by(id: 3733, custom_table_id: custom_table.id)

		effective_date = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
		base_rate1 = company.custom_fields.where(name: 'BaseRate1', custom_table_id: custom_table.id).first
		salary1 = company.custom_fields.where(name: 'Salary1', custom_table_id: custom_table.id).first
		annual_salary1 = company.custom_fields.where(name: 'Annual Salary1', custom_table_id: custom_table.id).first
		bonus1 = company.custom_fields.where(name: 'Bonus1', custom_table_id: custom_table.id).first
		commission1 = company.custom_fields.where(name: 'Commission1', custom_table_id: custom_table.id).first

		company.users.each do |user|
			base_rate_value = user.custom_field_values.find_by(custom_field_id: base_rate.id).try(:value_text)
			salary_value = user.custom_field_values.find_by(custom_field_id: salary.id).try(:value_text)
			annual_salary_value = user.custom_field_values.find_by(custom_field_id: annual_salary.id).try(:value_text)
			bonus_value = user.custom_field_values.find_by(custom_field_id: bonus.id).try(:value_text)
			commission_value = user.custom_field_values.find_by(custom_field_id: commission.id).try(:value_text)
      stock_option_value = user.custom_field_values.find_by(custom_field_id: stock_option.id).try(:value_text)

			currency_option_id = user.custom_field_values.find_by(custom_field_id: currency.id).try(:custom_field_option_id)
			currency_option = nil
			currency_option = currency.custom_field_options.find_by(id: currency_option_id).try(:option) if currency_option_id.present?

      pay_freq_option_id = user.custom_field_values.find_by(custom_field_id: pay_freq.id).try(:custom_field_option_id)
      pay_type_option_id = user.custom_field_values.find_by(custom_field_id: pay_type.id).try(:custom_field_option_id)

      if base_rate_value.present? || salary_value.present? || annual_salary_value.present? || bonus_value.present? || commission_value.present? || pay_freq_option_id.present? || pay_type_option_id.present? || stock_option_value.present?
				ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
				ctus.custom_snapshots.create(custom_field_id: effective_date.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
			end

			if  ctus.present?
				ctus.custom_snapshots.create(custom_field_id: base_rate1.id, custom_field_value: currency_option.to_s + "|" + base_rate_value.to_s)
				CustomFieldValue.set_custom_field_value(user, base_rate1.name, currency_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, base_rate1.name, base_rate_value, 'Currency Value', false, nil)

				ctus.custom_snapshots.create(custom_field_id: salary1.id, custom_field_value: currency_option.to_s + "|" + salary_value.to_s)
				CustomFieldValue.set_custom_field_value(user, salary1.name, currency_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, salary1.name, salary_value, 'Currency Value', false, nil)

				ctus.custom_snapshots.create(custom_field_id: annual_salary1.id, custom_field_value: currency_option.to_s + "|" + annual_salary_value.to_s)
				CustomFieldValue.set_custom_field_value(user, annual_salary1.name, currency_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, annual_salary1.name, annual_salary_value, 'Currency Value', false, nil)

				ctus.custom_snapshots.create(custom_field_id: bonus1.id, custom_field_value: currency_option.to_s + "|" + bonus_value.to_s)
				CustomFieldValue.set_custom_field_value(user, bonus1.name, currency_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, bonus1.name, bonus_value, 'Currency Value', false, nil)

				ctus.custom_snapshots.create(custom_field_id: commission1.id, custom_field_value: currency_option.to_s + "|" + commission_value.to_s)
				CustomFieldValue.set_custom_field_value(user, commission1.name, currency_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, commission1.name, commission_value, 'Currency Value', false, nil)

				ctus.custom_snapshots.create(custom_field_id: stock_option.id, custom_field_value: stock_option_value)

				ctus.custom_snapshots.create(custom_field_id: pay_freq.id, custom_field_value: pay_freq_option_id)

				ctus.custom_snapshots.create(custom_field_id: pay_type.id, custom_field_value: pay_type_option_id)
			end
		end
	end
end
