namespace :create_compensation_table_for_beat do
	task add_compensation_table_to_beat: :environment do
		company = Company.find_by(id: 110)
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

    pay_type = company.custom_fields.find_by(id: 3999)
    pay_type.update(custom_table_id: custom_table.id, position: 2)

    pay_schedule = company.custom_fields.find_by(id: 4000)
    pay_schedule.update(custom_table_id: custom_table.id, position: 3)

    compensation_change_reason = company.custom_fields.find_by(id: 4001)
    compensation_change_reason.update(custom_table_id: custom_table.id, position: 4)

		pay_rate1 = company.custom_fields.create(custom_field_params.merge({name: 'Pay Rate1', position: 1 }))
		pay_rate1.sub_custom_fields.create(name: 'Currency Type', field_type: 'mcq', help_text: 'Currency Type')
		pay_rate1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		pay_rate_gross1  = company.custom_fields.create(custom_field_params.merge({name: 'Pay Rate Gross1', position: 5 }))
		pay_rate_gross1.sub_custom_fields.create(name: 'Currency Type', field_type: 'mcq', help_text: 'Currency Type')
		pay_rate_gross1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

		pay_rate_net1 = company.custom_fields.create(custom_field_params.merge({name: 'Pay Rate Net1', position: 6 }))
		pay_rate_net1.sub_custom_fields.create(name: 'Currency Type', field_type: 'mcq', help_text: 'Currency Type')
		pay_rate_net1.sub_custom_fields.create(name: 'Currency Value', field_type: 'number', help_text: 'Currency Value')

	end

	task create_custom_snapshots_for_beat: :environment do
		company = Company.find_by(id: 110)
		#custom section fields
		pay_rate = company.custom_fields.where(id: 4008).first
		pay_rate_gross = company.custom_fields.where(id: 4006).first
		pay_rate_net = company.custom_fields.where(id: 4004).first
		currency_code = company.custom_fields.where(id: 4007).first

		#custom table fields
		custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:compensation])

    pay_type = company.custom_fields.find_by(id: 3999, custom_table_id: custom_table.id)
    pay_schedule = company.custom_fields.find_by(id: 4000, custom_table_id: custom_table.id)
    compensation_change_reason = company.custom_fields.find_by(id: 4001, custom_table_id: custom_table.id)

		effective_date = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
		pay_rate1 = company.custom_fields.where(name: 'Pay Rate1', custom_table_id: custom_table.id).first
		pay_rate_gross1 = company.custom_fields.where(name: 'Pay Rate Gross1', custom_table_id: custom_table.id).first
		pay_rate_net1 = company.custom_fields.where(name: 'Pay Rate Net1', custom_table_id: custom_table.id).first

		company.users.each do |user|
			pay_rate_value = user.custom_field_values.find_by(custom_field_id: pay_rate.id).try(:value_text)
			pay_rate_gross_value = user.custom_field_values.find_by(custom_field_id: pay_rate_gross.id).try(:value_text)
			pay_rate_net_value = user.custom_field_values.find_by(custom_field_id: pay_rate_net.id).try(:value_text)
			currency_code_option_id = user.custom_field_values.find_by(custom_field_id: currency_code.id).try(:custom_field_option_id)
			currency_code_option = nil
			currency_code_option = currency_code.custom_field_options.find_by(id: currency_code_option_id).try(:option) if currency_code_option_id.present?

      pay_type_option_id= user.custom_field_values.find_by(custom_field_id: pay_type.id).try(:custom_field_option_id)
      pay_schedule_option_id = user.custom_field_values.find_by(custom_field_id: pay_schedule.id).try(:custom_field_option_id)
      compensation_change_reason_option_id = user.custom_field_values.find_by(custom_field_id: compensation_change_reason.id).try(:custom_field_option_id)

      if pay_rate_value.present? || pay_rate_gross_value.present? || pay_rate_net_value.present? || pay_type_option_id.present? || pay_schedule_option_id.present? || compensation_change_reason_option_id.present?
				ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
				ctus.custom_snapshots.create(custom_field_id: effective_date.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
			end

			if pay_rate_value.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: pay_rate1.id, custom_field_value: currency_code_option.to_s + "|" + pay_rate_value.to_s)
				CustomFieldValue.set_custom_field_value(user, pay_rate1.name, currency_code_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, pay_rate1.name, pay_rate_value, 'Currency Value', false, nil)
			end

			if pay_rate_gross_value.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: pay_rate_gross1.id, custom_field_value: currency_code_option.to_s + "|" + pay_rate_gross_value.to_s)
				CustomFieldValue.set_custom_field_value(user, pay_rate_gross1.name, currency_code_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, pay_rate_gross1.name, pay_rate_gross_value, 'Currency Value', false, nil)
			end

			if pay_rate_net_value.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: pay_rate_net1.id, custom_field_value: currency_code_option.to_s + "|" + pay_rate_net_value.to_s)
				CustomFieldValue.set_custom_field_value(user, pay_rate_net1.name, currency_code_option, 'Currency Type', false, nil)
			  CustomFieldValue.set_custom_field_value(user, pay_rate_net1.name, pay_rate_net_value, 'Currency Value', false, nil)
			end

			if pay_type_option_id.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: pay_type.id, custom_field_value: pay_type_option_id)
			end

			if pay_schedule_option_id.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: pay_schedule.id, custom_field_value: pay_schedule_option_id)
			end

			if compensation_change_reason_option_id.present? && ctus.present?
				ctus.custom_snapshots.create(custom_field_id: compensation_change_reason.id, custom_field_value: compensation_change_reason_option_id)
			end

		end
	end
end
