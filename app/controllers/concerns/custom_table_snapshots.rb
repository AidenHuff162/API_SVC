module CustomTableSnapshots
  extend ActiveSupport::Concern
  include WebhookHandler

  def update_custom_snapshot_manager(user, current_user, effective_date = nil)
    company = user.company
    custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
    if custom_table.present?
      custom_table_user_snapshot = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).order("created_at").last
      if custom_table_user_snapshot.present? && (effective_date.nil? || custom_table_user_snapshot.state == "queue") && custom_table_user_snapshot.custom_snapshots.find_by(preference_field_id: 'man').present? && custom_table_user_snapshot.effective_date.strftime("%B %d, %Y") == effective_date.to_date.strftime("%B %d, %Y")
        manager_snapshot = custom_table_user_snapshot.custom_snapshots.find_by(preference_field_id: 'man')
        manager_snapshot.update!(custom_field_value: user.manager_id)
      else
        date = effective_date ? effective_date : user.start_date.strftime("%B %d, %Y")
        params = {custom_table_id: custom_table.id, edited_by_id: current_user.id, effective_date: date, terminate_job_execution: true, state: CustomTableUserSnapshot.states[:queue]}
        custom_table_user_snapshot = user.custom_table_user_snapshots.create(params)
        custom_table_user_snapshot.update(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?
        custom_table_user_snapshot.custom_snapshots.create!(manage_role_information_snapshot(user, custom_table, 'role_information', date, nil, false))
       ::CustomTables::ManageCustomSnapshotsJob.perform_later(custom_table_user_snapshot) if effective_date.nil?
      end
    end
  end

  def manage_role_information_snapshot(user, custom_table, table_property, effective_date = nil, ctus = nil, is_manager_reassigned = false, fields_data = nil)
    company = user.company
    custom_snapshots = []

    if custom_table.role_information? || custom_table.employment_status?
      preference_fields = company.prefrences["default_fields"].select { |preference_field| preference_field['profile_setup'] == 'custom_table' && preference_field['custom_table_property'] == table_property }
      preference_fields.each do |preference_field|
        if !['tt', 'td', 'ltw', 'efr'].include? preference_field['id']
          custom_field_value = fetch_custom_field_value(user, preference_field, false, table_property)
          if ctus.present? && custom_field_value.present?
            ctus.ctus_creation = true
          end
          custom_snapshots.push({ preference_field_id: preference_field['id'], custom_field_value: custom_field_value })
        end
      end
    end

    custom_fields = custom_table.custom_fields
    custom_fields.each do |custom_field|
      if custom_field.name.downcase == 'effective date' && custom_field.date? && effective_date.present?
        custom_field_value = effective_date
      elsif (user.termination_date.present? || is_manager_reassigned.present?) && custom_field.offboarding?.blank? && (custom_field.short_text?.present? || custom_field.long_text?.present?)
        custom_field_value = nil
      else
        custom_field_value = fetch_custom_field_value(user, custom_field, true, nil, fields_data)
        if ctus.present? && custom_field_value.present?
          ctus.ctus_creation = true
        end
      end
      custom_snapshots.push({ custom_field_id: custom_field.id, custom_field_value: custom_field_value })
    end
    return custom_snapshots
  end

  def fetch_custom_field_value(user, profile_field, is_custom_field = false, table_property = '', fields_data = nil)
    if is_custom_field.present?
      if profile_field.date?
        date_field_value = DateTime.parse(user.get_custom_field_value_text(profile_field.name, false, nil, nil, true)) rescue nil
        return date_field_value.strftime("%B %d, %Y") if date_field_value.present?
      elsif fields_data.present? && !profile_field.employment_status?
        custom_field = fields_data.select{ |field| field['custom_field_id'] == profile_field.id}[0]
        return custom_field['custom_field_value'] if custom_field.present?
      else
        custom_field_value = user.get_custom_field_value_text(profile_field.name, false, nil, nil, true, profile_field.id, false, true)
        if profile_field&.default_value && custom_field_value.blank?
          if profile_field.field_type == 'coworker'
            custom_field_value = JSON.parse(profile_field.default_value).objectID rescue ''
          else
            custom_field_value = profile_field&.custom_field_options.where(option: profile_field.default_value).take&.id
          end
        end
        return custom_field_value
      end
    else
      if table_property == 'role_information'
        case profile_field['id']
          when 'man'
            return user.manager_id.try(:to_i)
          when 'jt'
            return user.title
          when 'dpt'
            return user.team_id.try(:to_i)
          when 'loc'
            return user.location_id.try(:to_i)
          else
            return nil
        end
      elsif table_property == 'employment_status'
        if profile_field['id'] == 'st'
          if user.termination_date.present?
            return 'inactive'
          else
            return user.state
          end
        end
      end
    end
  end

  def set_emp_table_params_for_offboarding(params, user)
    params.merge!( terminated_data:  {last_day_worked: user.last_day_worked, eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type}, is_terminated: true)
    params.merge!( terminate_callback: true ) if user.termination_date > Date.today
  end

  def manage_offboarding_ctus_creation (user, custom_table, params, fields_data)
    custom_table_user_snapshot = user.custom_table_user_snapshots.create!(params)
    custom_snapshots = manage_role_information_snapshot(user, custom_table, custom_table.custom_table_property, user.termination_date.strftime("%B %d, %Y"), custom_table_user_snapshot, false, fields_data)
    if custom_table_user_snapshot.ctus_creation.present?
      custom_snapshots.try(:each) do |custom_snapshot|
        custom_table_user_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
      end
      ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot)  if custom_table_user_snapshot.applied?
    elsif custom_table_user_snapshot.ctus_creation.blank?
      custom_table_user_snapshot.destroy! if custom_table_user_snapshot.id.present?
    end
  end

  def manage_offboard_user_snapshots(user, current_user, fields_data)
    company = user.company
    user.custom_table_user_snapshots.update_all(state: CustomTableUserSnapshot.states[:processed]) if user.departed?
    company.custom_tables.each do |custom_table|
      if custom_table.present? && (custom_table.employment_status? || custom_table.custom_fields.where(display_location: CustomField.display_locations[:offboarding]).count > 0)
        params = {custom_table_id: custom_table.id, edited_by_id: current_user.id, effective_date: user.termination_date.strftime("%B %d, %Y"), state: CustomTableUserSnapshot.states[:queue], terminate_job_execution: true}
        params.merge!(state: 'applied', terminate_callback: true) if user.departed?
        if custom_table.custom_table_property == 'employment_status'
          set_emp_table_params_for_offboarding(params, user)
        end
        manage_offboarding_ctus_creation(user, custom_table, params, fields_data)
      end
    end
  end

  def manage_onboard_user_snapshots(user, current_user)
    company = user.company
    custom_tables= []
    company.custom_tables.each do |custom_table|

      if custom_table.present?
        custom_table_user_snapshot = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).order("created_at").last
        custom_table_user_snapshot = user.custom_table_user_snapshots.new({custom_table_id: custom_table.id, state: CustomTableUserSnapshot.states[:applied], edited_by_id: current_user.id, effective_date: user.start_date.strftime("%B %d, %Y"), terminate_job_execution: true}) if custom_table_user_snapshot.blank?

        custom_snapshots = manage_role_information_snapshot(user, custom_table, custom_table.custom_table_property, user.start_date.strftime("%B %d, %Y"), custom_table_user_snapshot, false)

        if custom_table_user_snapshot.ctus_creation.present?
          custom_snapshots.try(:each) do |custom_snapshot|
            custom_table_user_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
          end
          custom_table_user_snapshot.save! if custom_table_user_snapshot.id.blank?
          ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.present?

        elsif custom_table_user_snapshot.ctus_creation.blank?
          custom_table_user_snapshot.destroy! if custom_table_user_snapshot.id.present?
        end
      end
    end
  end

  def delete_employment_status_terminated_ctus(user, current_user)
    custom_table = user.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
    applied_ctus = CustomTableUserSnapshot.where(custom_table_id: custom_table.id, user_id: user.id, is_terminated: true).first if custom_table.present?
    applied_ctus.destroy! if applied_ctus.present?
  end

  def restore_previous_snapshot_values user
    if user.present?
      user.custom_table_user_snapshots.where(state: CustomTableUserSnapshot.states[:applied]).try(:each) do |ctus|
        ::CustomTables::ManageCustomSnapshotsJob.perform_now(ctus)
      end
    end
  end

  def manage_rehired_user_snapshots user, current_user
    company = user.company
    user.custom_table_user_snapshots.update_all(state: CustomTableUserSnapshot.states[:processed])

    company.custom_tables.each do |custom_table|
      ctus = user.custom_table_user_snapshots.new(custom_table_id: custom_table.id, edited_by_id: current_user.id, effective_date: user.start_date.strftime("%B %d, %Y"), state: CustomTableUserSnapshot.states[:applied], terminate_callback: true)
      custom_snapshot_attributes = manage_role_information_snapshot(user, custom_table, custom_table.custom_table_property, user.start_date.strftime("%B %d, %Y"), ctus, false)
      if ctus.ctus_creation.present?
        ctus.save!
        ctus.custom_snapshots.create(custom_snapshot_attributes)
        ::CustomTables::ManageCustomSnapshotsJob.perform_now(ctus) if ctus.present? && ctus.applied?
      end
    end
  end

  def manage_reassign_users_snapshots user_data, current_user, current_company
    user_data.each do |user_data|
      user = current_company.users.find_by(id: user_data[:user_id]) if user_data[:user_id].present?
      offboarded_user = current_company.users.find_by(id: user_data[:terminated_user_id]) if user_data[:terminated_user_id].present?
      if user.present? && user_data[:manager_id].present? && offboarded_user.present?
        user.manager_id = user_data[:manager_id]
        custom_table = current_company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
        ctus = user.custom_table_user_snapshots.create(custom_table_id: custom_table.id, effective_date: offboarded_user.termination_date.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: current_user.id, state: CustomTableUserSnapshot.states[:queue]) if custom_table.present?
        if ctus.present?
          ctus.custom_snapshots.create(manage_role_information_snapshot(user, custom_table, 'role_information', offboarded_user.termination_date.strftime("%B %d, %Y"), nil, true))
          ::CustomTables::ManageCustomSnapshotsJob.perform_now(ctus)
        end
      end
    end
  end

  def manage_reassing_manager_snapshots data, current_user
    user_ids, effective_date, manager_id= data[:user_ids], data[:effective_date], data[:manager_id]
    company = current_user.company
    users = company.users.where(id: user_ids).where.not(id: manager_id) #skip manager to assign himself as an manager
    manager = company.users.find_by(id: manager_id)
    return if manager.nil? || company.nil?
    role_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
    
    unless company.is_using_custom_table && role_table
      users.each do |user|
        temp_user = user.dup
        temp_user.id = user.id
        user.update!(manager_id: manager_id)
        ::IntegrationsService::UserIntegrationOperationsService.new(temp_user).perform('update', user)
        trigger_webhook(company, 'profile_changed', temp_user.attributes, {manager_id: manager_id}, nil, nil, false)
      end
      return
    end
    users.each do |user|
      temp_user = user.dup
      temp_user.id = user.id
      user.assign_attributes(manager_id: manager.id, manager_terminate_callback: true)
      snapshots = user.custom_table_user_snapshots.where(custom_table_id: role_table.id).order("created_at").last
      if data[:is_today] || !snapshots.present?
        user.save! 
        Users::ReassignManagerActivitiesJob.perform_async(company.id, user.id, temp_user.manager_id) if temp_user.manager_id != user.manager_id
        ::IntegrationsService::UserIntegrationOperationsService.new(temp_user).perform('update', user)
        trigger_webhook(company, 'job_details_changed', temp_user.attributes, user, role_table.name, data[:effective_date], false)
      end
      update_custom_snapshot_manager(user, current_user, effective_date.to_date.strftime("%B %d, %Y"))
    end
  end

  def trigger_webhook(company, type, attributes, params, ctus = nil, date = nil, profile = false)
    send_updates_to_webhooks(company, {event_type: type, attributes: attributes, params_data: params, ctus_name: ctus, effective_date: date, profile_update: profile })
  end
end
