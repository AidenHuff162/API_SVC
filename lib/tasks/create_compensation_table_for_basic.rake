namespace :compensation_table_creation_for_basic do
	task :add_compensation_table_to_custom_tables, [:company_id, :pay_frequency_id, :rate_type_id] => :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		custom_table = company.custom_tables.create!(name: 'Compensation', table_type: CustomTable.table_types[:timeline], custom_table_property: CustomTable.custom_table_properties[:compensation], position: 2)

		custom_field_params = {
			locks: {all_locks: false, options_lock: false},
			collect_from: :admin,
			required: false,
			custom_table_id: custom_table.id,
			section: nil
    }

		pay_rate1 = company.custom_fields.create!(custom_field_params.merge({name: 'Pay Rate1', field_type: CustomField.field_types[:currency], position: 2}))
    pay_rate1.sub_custom_fields.create!(name: 'Currency Type', field_type: 'short_text', help_text: 'Currency Type')
    pay_rate1.sub_custom_fields.create!(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

    pay_frequency = company.custom_fields.find_by(id: args.pay_frequency_id)
    pay_frequency.update(custom_table_id: custom_table.id, position: 1, section: nil)

    rate_type = company.custom_fields.find_by(id: args.rate_type_id)
    rate_type.update(custom_table_id: custom_table.id, position: 3, section: nil)
	end

	task :create_custom_table_user_sanpshots_for_compensation_table, [:company_id, :pay_frequency_id, :rate_type_id, :pay_rate_id]=> :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		if company.present?
			compensation_table = company.custom_tables.where(custom_table_property: CustomTable.custom_table_properties[:compensation]).first

			if compensation_table.present?
				effective_date = company.custom_fields.where(name: 'Effective Date', custom_table_id: compensation_table.id).first
				pay_rate1 = company.custom_fields.where(name: 'Pay Rate1', custom_table_id: compensation_table.id).first
			end

			pay_frequency = company.custom_fields.find_by(id: args.pay_frequency_id)
    	rate_type = company.custom_fields.find_by(id: args.rate_type_id)
    	pay_rate = company.custom_fields.find_by(id: args.pay_rate_id)

    	company.users.all.each do |user|
    		pay_frequency_option_id = user.custom_field_values.find_by(custom_field_id: pay_frequency.id).try(:custom_field_option_id)
    		rate_type_option_id = user.custom_field_values.find_by(custom_field_id: rate_type.id).try(:custom_field_option_id)
				pay_rate_value = user.custom_field_values.find_by(custom_field_id: pay_rate.id).try(:value_text)

				if compensation_table.present? && (pay_frequency_option_id.present? || rate_type_option_id.present? || pay_rate_value.present?)
					ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: compensation_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
					if ctus.present?
						ctus.custom_snapshots.create!(custom_field_id: effective_date.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: effective_date.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
						ctus.custom_snapshots.create!(custom_field_id: pay_frequency.id, custom_field_value: pay_frequency_option_id)
						ctus.custom_snapshots.create!(custom_field_id: rate_type.id, custom_field_value: rate_type_option_id)
						ctus.custom_snapshots.create!(custom_field_id: pay_rate1.id, custom_field_value: "USD|".to_s + pay_rate_value.to_s.gsub(",",""))
						CustomFieldValue.set_custom_field_value(user, pay_rate1.name, "USD", 'Currency Type', false, nil)
						CustomFieldValue.set_custom_field_value(user, pay_rate1.name, pay_rate_value.to_s.gsub(",",""), 'Currency Value', false, nil)
					end
				end
    	end
		end
	end
end
