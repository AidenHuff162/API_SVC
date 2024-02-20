namespace :create_compensation_table_for_coursehero do
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

		pay_rate1 = company.custom_fields.create!(custom_field_params.merge({name: 'Pay Rate1', field_type: CustomField.field_types[:currency], position: 1}))
    pay_rate1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    pay_rate1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    bonnus1 = company.custom_fields.create!(custom_field_params.merge({name: 'Bonus1', field_type: CustomField.field_types[:currency], position: 5}))
    bonnus1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    bonnus1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    stock_option1 = company.custom_fields.create!(custom_field_params.merge({name: 'Stock Options1', field_type: CustomField.field_types[:currency], position: 4}))
    stock_option1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    stock_option1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    pay_frequency = company.custom_fields.find_by(id: 2464)
    pay_frequency.update(custom_table_id: custom_table.id, position: 2, section: nil)

    rate_type = company.custom_fields.find_by(id: 2465)
    rate_type.update(custom_table_id: custom_table.id, position: 3, section: nil)
	end

	task :create_custom_table_user_sanpshots_for_compensation_table, [:company_id] => :environment do |t, args|
		company = Company.find(args.company_id)
		if company.present?
			compensation_table = company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).first

			if compensation_table.present?
				effective_date = company.custom_fields.where(name: 'Effective Date', custom_table_id: compensation_table.id).first
				pay_rate1 = company.custom_fields.where(name: 'Pay Rate1', custom_table_id: compensation_table.id).first
				bonnus1 = company.custom_fields.where(name: 'Bonus1', custom_table_id: compensation_table.id).first
				stock_option1 = company.custom_fields.where(name: 'Stock Options1', custom_table_id: compensation_table.id).first
			end

    	pay_rate = company.custom_fields.find_by(id: 2461)
    	pay_frequency = company.custom_fields.find_by(id: 2464)
    	rate_type = company.custom_fields.find_by(id: 2465)
    	stock_option = company.custom_fields.find_by(id: 2462)
    	bonus = company.custom_fields.find_by(id: 2463)

    	company.users.all.each do |user|
				pay_rate_value = user.custom_field_values.find_by(custom_field_id: pay_rate.id).try(:value_text)
				stock_option_value = user.custom_field_values.find_by(custom_field_id: stock_option.id).try(:value_text)
				bonus_value = user.custom_field_values.find_by(custom_field_id: bonus.id).try(:value_text)

				pay_frequency_option_id = user.custom_field_values.find_by(custom_field_id: pay_frequency.id).try(:custom_field_option_id)
				rate_type_option_id = user.custom_field_values.find_by(custom_field_id: rate_type.id).try(:custom_field_option_id)

				if compensation_table.present? && (pay_rate_value.present? || stock_option_value.present? || bonus_value.present? || pay_frequency_option_id.present? || rate_type_option_id.present?)
					ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: compensation_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
					if ctus.present?
						ctus.custom_snapshots.create!(custom_field_id: effective_date.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: effective_date.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
						ctus.custom_snapshots.create!(custom_field_id: pay_frequency.id, custom_field_value: pay_frequency_option_id)
						ctus.custom_snapshots.create!(custom_field_id: rate_type.id, custom_field_value: rate_type_option_id)

						currency_symbol = 'USD'
						ctus.custom_snapshots.create!(custom_field_id: bonnus1.id, custom_field_value: currency_symbol.to_s + "|" + bonus_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, bonnus1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, bonnus1.name, bonus_value.to_s.gsub(",",""), 'Currency Value', false, nil)

						ctus.custom_snapshots.create!(custom_field_id: stock_option1.id, custom_field_value: currency_symbol.to_s + "|" + stock_option_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, stock_option1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, stock_option1.name, stock_option_value.to_s.gsub(",",""), 'Currency Value', false, nil)

						ctus.custom_snapshots.create!(custom_field_id: pay_rate1.id, custom_field_value: currency_symbol.to_s + "|" + pay_rate_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, pay_rate1.name, currency_symbol, 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, pay_rate1.name, pay_rate_value.to_s.gsub(",",""), 'Currency Value', false, nil)
					end
				end
			end
		end
	end
end
