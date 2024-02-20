namespace :create_role_info_table do

	desc 'Updating the preference fields of comapnies'
	task :update_companies_preference_fields, [:company_id]=> :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		prefrences = company.prefrences
		prefrences['default_fields'].each do |default_field|

			case default_field['id']
			when 'jt'
				default_field['profile_setup'] = 'custom_table'
				default_field['custom_table_property'] = 'role_information'
				default_field['section'] = nil
				default_field['position'] = 1
			when 'loc'
				default_field['profile_setup'] = 'custom_table'
				default_field['custom_table_property'] = 'role_information'
				default_field['section'] = nil
				default_field['position'] = 2
			when 'dpt'
				default_field['profile_setup'] = 'custom_table'
				default_field['custom_table_property'] = 'role_information'
				default_field['section'] = nil
				default_field['position'] = 3
			when 'man'
				default_field['profile_setup'] = 'custom_table'
				default_field['custom_table_property'] = 'role_information'
				default_field['section'] = nil
				default_field['position'] = 4
			end
			company.update(prefrences: prefrences)
		end
	end

	desc 'Adding Role Info Table into the Table Structure'
	task :add_role_info_table_into_table_structure, [:company_id]=> :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		company.custom_tables.find_or_initialize_by(name: 'Role Information', table_type: CustomTable.table_types[:timeline], custom_table_property: CustomTable.custom_table_properties[:role_information], position: 1 ).save
	end

	desc 'Creating Snapshots for role information table'
	task :create_custom_snapshots_for_users, [:company_id]=> :environment do |t, args|
		company = Company.find_by(id: args.company_id)
		custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
		company.users.each do |user|
			if custom_table.present?
				ctus = user.custom_table_user_snapshots.create(effective_date: user.start_date.strftime("%B %d, %Y"), edited_by_id: nil, custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
				ctus.custom_snapshots.create!(preference_field_id: 'jt', custom_field_value: user.title)
				ctus.custom_snapshots.create!(preference_field_id: 'loc', custom_field_value: user.location.try(:id))
				ctus.custom_snapshots.create!(preference_field_id: 'dpt', custom_field_value: user.team.try(:id))
				ctus.custom_snapshots.create!(preference_field_id: 'man', custom_field_value: user.manager.try(:id))
				ed = company.custom_fields.where(name: 'Effective Date', custom_table_id: custom_table.id).first
				ctus.custom_snapshots.create!(custom_field_id: ed.id, custom_field_value: user.start_date.strftime("%B %d, %Y"))
				user.custom_field_values.find_or_initialize_by(custom_field_id: ed.id).update(value_text: user.start_date.strftime("%B %d, %Y"))
			end
		end
	end
end
