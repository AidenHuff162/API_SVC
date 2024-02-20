namespace :employment_status_smart_assignment_tasks do

  task lock_and_migrate_employment_status_to_group_type: :environment do

    puts "---- Locking and Updating the integration group to custom group of all Employment Status Fields ----"

    CustomField.where(field_type: 13).update_all(integration_group: 'custom_group', locks: {options_lock: true, all_locks: true})

    puts "---- Completed ----"

  end

end
