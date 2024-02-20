namespace :create_employment_status_table do

	desc 'Creating Employment Status Custom Table with employment status and effective date custom fields'
	task :add_employment_status_table_to_companies, [:company_id]=> :environment do |t, args|

		custom_field_params = {
			locks: {all_locks: false, options_lock: false},
			required: true,
			collect_from: :admin,
			section: nil
    }

		custom_table_params = {
			name: 'Employment Status',
			table_type: CustomTable.table_types[:timeline],
			custom_table_property: CustomTable.custom_table_properties[:employment_status]
		}

		company = Company.find_by(id: args.company_id)
		#For Cohort 1
		custom_table = company.custom_tables.find_or_initialize_by(custom_table_params)
		custom_table.update(position: 0)

		employment_status_custom_field = company.custom_fields.find_or_initialize_by(name: 'Employment Status', field_type: CustomField.field_types[:employment_status])
		employment_status_custom_field.update(custom_field_params.merge!({position: 1, custom_table_id: custom_table.id }))
		employment_status_custom_field.custom_field_options.find_or_initialize_by(option: 'Full Time').update( position: 0)
		employment_status_custom_field.custom_field_options.find_or_initialize_by(option: 'Part Time').update( position: 1)
		employment_status_custom_field.custom_field_options.find_or_initialize_by(option: 'Terminated').update( position: 2)

		notes = company.custom_fields.find_or_initialize_by(name: 'Notes', field_type: CustomField.field_types[:short_text])
		notes.update({locks: {all_locks: false, options_lock: false}, required: false, collect_from: :admin, section: nil, position: 3, custom_table_id: custom_table.id})


		preferences = company.prefrences
		default_fields = preferences['default_fields']

		default_fields.each do |df|
			if df['id'] == 'st'
				df['profile_setup'] = 'custom_table'
				df['custom_table_property'] = 'employment_status'
				df['section'] = nil
				df['position'] = 2
			elsif df['id'] == 'td'
				df['profile_setup'] = 'custom_table'
				df['custom_table_property'] = 'employment_status'
				df['section'] = nil
				df['position'] = 4
			elsif df['id'] == 'ltw'
				df['profile_setup'] = 'custom_table'
				df['custom_table_property'] = 'employment_status'
				df['section'] = nil
				df['position'] = 5
			elsif df['id'] == 'tt'
				df['profile_setup'] = 'custom_table'
				df['custom_table_property'] = 'employment_status'
				df['section'] = nil
				df['position'] = 6
			elsif df['id'] == 'efr'
				df['profile_setup'] = 'custom_table'
				df['custom_table_property'] = 'employment_status'
				df['section'] = nil
				df['position'] = 7
			end
		end

		company.update_column(:prefrences, preferences)
	end


	desc 'Creating Snapshots for users of Employment Status Custom table'
	task :create_custom_snapshots_for_active_user, [:company_id]=> :environment do |t, args|

		company = Company.find_by(id: args.company_id)
		custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
		if custom_table.present?

			users = company.users
			users.each do |user|
				if !user.departed?

					if user.start_date.present?
						ctus = user.custom_table_user_snapshots.create!(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
						ctus.custom_snapshots.create!(preference_field_id: 'st', custom_field_value: user.state)
						es = company.custom_fields.where(name: 'Employment Status', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: es.id, custom_field_value: user.custom_field_values.find_by(custom_field_id: es.id).try(:custom_field_option_id))
						notes = company.custom_fields.where(name: 'Notes', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: notes.id, custom_field_value: nil)
						ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: ed.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
					end

					if user.termination_date.present? && user.termination_date >= Date.today
						ctus = user.custom_table_user_snapshots.create!(effective_date: user.termination_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:queue], is_terminated: true, terminate_callback: true)

						ctus.custom_snapshots.create!(preference_field_id: 'st', custom_field_value: 'inactive')
						es = company.custom_fields.where(name: 'Employment Status', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: es.id, custom_field_value: es.custom_field_options.find_by(option: 'Terminated').try(:id))
						notes = company.custom_fields.where(name: 'Notes', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: notes.id, custom_field_value: nil)
						ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.termination_date.strftime("%B %d, %Y"))
					end
				end
			end
		end
	end


	desc 'Creating Snapshots for departed users of Employment Status Custom table'
	task :create_custom_snapshots_for_inactive_user, [:company_id]=> :environment do |t, args|

		company = Company.find_by(id: args.company_id)
		custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
		if custom_table.present?

			users = company.users
			users.each do |user|
				if user.departed?
					if user.start_date.present? && user.termination_date.present? && user.start_date < user.termination_date
						ctus = user.custom_table_user_snapshots.create!(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:processed], terminate_callback: true)
						ctus.custom_snapshots.create!(preference_field_id: 'st', custom_field_value: 'active')
						es = company.custom_fields.where(name: 'Employment Status', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: es.id, custom_field_value: user.custom_field_values.find_by(custom_field_id: es.id).try(:custom_field_option_id))
						notes = company.custom_fields.where(name: 'Notes', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: notes.id, custom_field_value: nil)
						ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
					end

					if user.start_date.present? && !user.termination_date.present?
						ctus = user.custom_table_user_snapshots.create!(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], is_terminated: true, terminate_callback: true)
						ctus.custom_snapshots.create!(preference_field_id: 'st', custom_field_value: user.state)
						es = company.custom_fields.where(name: 'Employment Status', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: es.id, custom_field_value: user.custom_field_values.find_by(custom_field_id: es.id).try(:custom_field_option_id))
						notes = company.custom_fields.where(name: 'Notes', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: notes.id, custom_field_value: nil)
						ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: ed.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
					end

					if user.termination_date.present?
						ctus = user.custom_table_user_snapshots.create!(effective_date: user.termination_date.strftime("%B %d, %Y"),
							edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied],
							is_terminated: true, terminate_callback: true, terminated_data: { last_day_worked: user.last_day_worked,
						 	eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type })
						
						ctus.custom_snapshots.create!(preference_field_id: 'st', custom_field_value: user.state)

						es = company.custom_fields.where(name: 'Employment Status', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: es.id, custom_field_value: es.custom_field_options.find_by(option: 'Terminated').try(:id))

						notes = company.custom_fields.where(name: 'Notes', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: notes.id, custom_field_value: nil)
						ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
						ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.termination_date.strftime("%B %d, %Y"))
						user.custom_field_values.find_or_initialize_by(custom_field_id: es.id).update(custom_field_option_id: es.custom_field_options.find_by(option: 'Terminated').try(:id)) if user.departed?
						user.custom_field_values.find_or_initialize_by(custom_field_id: ed.id).update(value_text: user.termination_date.strftime("%B %d, %Y"))
					end
				end
			end
		end
	end
end

