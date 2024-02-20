class CustomTables::CustomTableSnapshotManagement

  def onboarding_management(user, employee, company)
    company.custom_tables.try(:find_each) do |custom_table|
      custom_table_user_snapshot = employee.custom_table_user_snapshots.find_or_initialize_by(custom_table_id: custom_table.id)

      custom_snapshots = build_custom_snapshots(employee, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, employee.start_date.strftime("%B %d, %Y"), false)

      if custom_table_user_snapshot.ctus_creation.present?
        custom_table_user_snapshot.assign_attributes(state: CustomTableUserSnapshot.states[:applied], edited_by_id: user.id, effective_date: employee.start_date.strftime("%B %d, %Y"), terminate_callback: true)
        custom_table_user_snapshot.assign_attributes(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?

        custom_table_user_snapshot.save!

        custom_snapshots.try(:each) do |custom_snapshot|
          custom_table_user_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
        end
        ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.present?
      end
    end
  end

  def change_manager_custom_snapshot(user, employee, company)
    custom_table = company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
    today_date = DateTime.now.utc.in_time_zone(custom_table.company.time_zone).to_date

    custom_table_user_snapshot = employee.custom_table_user_snapshots.find_or_initialize_by(custom_table_id: custom_table.id, effective_date: today_date)
    custom_snapshots = build_custom_snapshots(employee, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, today_date, false)

    unless custom_table_user_snapshot.id?
      custom_table_user_snapshot.assign_attributes(state: CustomTableUserSnapshot.states[:queue], edited_by_id: user.id, terminate_job_execution: true)
      custom_table_user_snapshot.assign_attributes(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?

      custom_table_user_snapshot.save!
    end

    custom_snapshots.try(:each) do |custom_snapshot|
      custom_table_user_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
    end
    return if custom_table_user_snapshot.blank?

    ::CustomTables::ManageCustomSnapshotsJob.perform_later(custom_table_user_snapshot)
  end

  def offboarding_management(user, employee, company, default_custom_snapshots, lde_data)
    CustomTableUserSnapshot.get_future_termination_based_snapshots(employee.id, employee.termination_date.strftime("%B %d, %Y")).each do |ctus|
      ctus.terminate_callback = true if ctus.custom_table.employment_status?
      ctus.destroy
    end

    company.custom_tables.each do |custom_table|
      if (custom_table.present? && (custom_table.employment_status? ||
          is_valid_role_information?(custom_table, employee, lde_data) || 
          does_table_have_offboarding_fields?(custom_table, employee)))
        params = { custom_table_id: custom_table.id, edited_by_id: user.id, effective_date: employee.termination_date.strftime("%B %d, %Y"), state: CustomTableUserSnapshot.states[:queue],
          terminate_job_execution: true }
        params[:request_state] = CustomTableUserSnapshot.request_states[:approved] if custom_table.is_approval_required.present?

        if custom_table.employment_status?
          params.merge!(terminated_data: { last_day_worked: employee.last_day_worked, eligible_for_rehire: employee.eligible_for_rehire, termination_type: employee.termination_type },
            is_terminated: true)
          params.merge!(terminate_callback: true) if employee.termination_date > Date.today
        end
        # params.merge!(state: CustomTableUserSnapshot.states[:applied]) if employee.departed?

        custom_table_user_snapshot = employee.custom_table_user_snapshots.new(params)
        custom_snapshots = build_custom_snapshots(employee, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, employee.termination_date.strftime("%B %d, %Y"), false, default_custom_snapshots, lde_data)

        if custom_table_user_snapshot.ctus_creation.present?
          CustomTableUserSnapshot.bypass_approval = true
          custom_table_user_snapshot.save!
          CustomTableUserSnapshot.bypass_approval = false
          custom_table_user_snapshot.custom_snapshots.create(custom_snapshots)
          Activity.create(description: ' has made a change to ' + custom_table.name , activity_type: 'CustomTableUserSnapshot', activity_id: custom_table_user_snapshot.id, agent_id: user.id)
          if custom_table_user_snapshot.applied?
            CustomTables::AssignSnapshotsAndDocuments.perform_later(employee.id, user.id, custom_table_user_snapshot)
          end
        end
      end
    end
  end

  def manage_manager_form_snapshots(user, employee, company, default_custom_snapshots)
    effective_date = DateTime.now.utc.in_time_zone(company.time_zone).to_date

    company.custom_tables.each do |custom_table|
      if custom_table.present? && (default_custom_snapshots.pluck(:custom_field_id)&.map(&:to_s) & custom_table.get_field_ids_associated()&.map(&:to_s)).any?

        params = { custom_table_id: custom_table.id, edited_by_id: user.id, effective_date: effective_date, state: CustomTableUserSnapshot.states[:queue], terminate_job_execution: true }
        params[:request_state] = CustomTableUserSnapshot.request_states[:approved] if custom_table.is_approval_required.present?

        custom_table_user_snapshot = employee.custom_table_user_snapshots.new(params)
        custom_snapshots = build_custom_snapshots(employee, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, effective_date, false, default_custom_snapshots, nil, true)

        if custom_table_user_snapshot.ctus_creation.present?
          CustomTableUserSnapshot.bypass_approval = true
          custom_table_user_snapshot.save!
          CustomTableUserSnapshot.bypass_approval = false
          custom_table_user_snapshot.custom_snapshots.create(custom_snapshots)
          Activity.create(description: ' has made a change to ' + custom_table.name , activity_type: 'CustomTableUserSnapshot', activity_id: custom_table_user_snapshot.id, agent_id: user.id)
          ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.reload.applied?
        end
      end
    end
  end

  def reassigning_manager_offboard_custom_snapshots(user, employee_data, current_company)
    custom_table = current_company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:role_information])
    return unless custom_table.present?

    employee_data.each do |employee_data|
      employee = current_company.users.find_by(id: employee_data[:user_id]) if employee_data[:user_id].present?
      offboarded_user = current_company.users.find_by(id: employee_data[:terminated_user_id]) if employee_data[:terminated_user_id].present?
      if employee.present? && offboarded_user.present?
        employee.manager_id = employee_data[:manager_id]
        CustomTableUserSnapshot.bypass_approval = true
        params = {custom_table_id: custom_table.id, effective_date: offboarded_user.last_day_worked.strftime("%B %d, %Y"), terminate_job_execution: true, edited_by_id: user.id, state: CustomTableUserSnapshot.states[:queue]}
        params[:request_state] = CustomTableUserSnapshot.request_states[:approved] if custom_table.is_approval_required.present?

        custom_table_user_snapshot = employee.custom_table_user_snapshots.create(params)
        CustomTableUserSnapshot.bypass_approval = false
        if custom_table_user_snapshot.present?
          custom_table_user_snapshot.custom_snapshots.create(build_custom_snapshots(employee, custom_table, 'role_information', custom_table_user_snapshot, offboarded_user.termination_date.strftime("%B %d, %Y"), true))
          if custom_table_user_snapshot.reload.applied?
            ::CustomTables::ManageCustomSnapshotsJob.perform_later(custom_table_user_snapshot)
          end
        end
      end
    end
  end

  def delete_terminated_custom_snapshot(user, current_user)
    custom_table = user.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[:employment_status])
    applied_snapshot = custom_table.custom_table_user_snapshots.where(user_id: user.id, is_terminated: true).first if custom_table.present?
    if applied_snapshot.present?
      applied_snapshot.terminate_callback = true
      applied_snapshot.destroy!
    end
  end

  def rehiring_management user, current_user
    company = user.company
    user.custom_table_user_snapshots.update_all(is_applicable: false, state: CustomTableUserSnapshot.states[:processed]) if company&.custom_tables.present?

    company.custom_tables.each do |custom_table|
      ctus = user.custom_table_user_snapshots.find_or_initialize_by(custom_table_id: custom_table.id, edited_by_id: current_user&.id, effective_date: user.start_date.strftime("%B %d, %Y"))
      custom_snapshot_attributes = build_custom_snapshots(user, custom_table, custom_table.custom_table_property, ctus, user.start_date.strftime("%B %d, %Y"))
      if ctus.ctus_creation.present?
        ctus.assign_attributes(state: CustomTableUserSnapshot.states[:applied], is_applicable: true, terminate_callback: true)
        ctus.assign_attributes(request_state: CustomTableUserSnapshot.request_states[:approved]) if custom_table.is_approval_required.present?

        custom_snapshot_attributes.try(:each) do |custom_snapshot|
          ctus.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
        end
        ctus.save! if ctus.present?
        ::CustomTables::ManageCustomSnapshotsJob.perform_now(ctus) if ctus.present? && ctus.reload.applied?
      end
    end
  end

  def pending_hire_management current_user, user, company, pending_hire
    attributes = pending_hire.changed_info.map{|field| field[:attribute]}
    user.set_fields_by_pending_hire(pending_hire.changed_info, company.is_using_custom_table) if (['first_name', 'last_name', 'start_date', 'phone_number', 'line1', 'line2', 'city', 'address_state', 'zip'] & attributes).present?
    custom_table_property = company.prefrences["default_fields"].map{|f|  f["custom_table_property"] if attributes.include?(f["id"])}.compact.uniq
    properties = CustomTable.custom_table_properties.select{ |k,v| v if custom_table_property.include?(k) }.values
    custom_table_ids = company.custom_fields.where(name: attributes).where.not(custom_table_id: nil).pluck(:custom_table_id).uniq rescue nil
    effective_date = attributes.include?("start_date") ? fetch_pendinghire_custom_field(pending_hire, {"name" => "start_date"})[:new].to_date : Date.today
    custom_tables = company.custom_tables.where("id IN (?) OR custom_table_property IN (?) ", custom_table_ids, properties).distinct rescue nil
    custom_tables.each do |custom_table|
      if custom_table.present?
        params = { custom_table_id: custom_table.id, edited_by_id: current_user.id, effective_date: effective_date.strftime("%B %d, %Y"), state: CustomTableUserSnapshot.states[:queue] }

        custom_table_user_snapshot = user.custom_table_user_snapshots.new(params)
        custom_snapshots = build_custom_snapshots(user, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, effective_date.strftime("%B %d, %Y"), false, pending_hire)
        if custom_table_user_snapshot.ctus_creation.present?
          CustomTableUserSnapshot.bypass_approval = true
          custom_table_user_snapshot.save!
          CustomTableUserSnapshot.bypass_approval = false
          custom_table_user_snapshot.custom_snapshots.create(custom_snapshots)
          ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.reload.applied?
        end
      end
    end
  end

  def public_api_management custom_table, user
    effective_date = DateTime.now.utc.in_time_zone(custom_table.company.time_zone).to_date
    custom_table_user_snapshot = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id, integration_type: CustomTableUserSnapshot.integration_types[:public_api], effective_date: effective_date,
      state: CustomTableUserSnapshot.states[:applied], is_applicable: true).take

    if custom_table_user_snapshot.present?
      custom_snapshots = build_custom_snapshots(user, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, effective_date)

      if custom_table.employment_status? && (user.last_day_worked.present? || user.termination_date.present? || user.termination_type.present?)
        custom_table_user_snapshot.assign_attributes(terminated_data: { last_day_worked: user.last_day_worked, eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type },
            is_terminated: true, terminate_callback: true)
        custom_table_user_snapshot.save!
      end

      custom_snapshots.try(:each) do |custom_snapshot|
          custom_table_user_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)
        end
      ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.reload.applied?
    else
      params = { custom_table_id: custom_table.id, effective_date: effective_date, state: CustomTableUserSnapshot.states[:queue],
       integration_type: CustomTableUserSnapshot.integration_types[:public_api] }
      params[:request_state] = CustomTableUserSnapshot.request_states[:approved] if custom_table.is_approval_required.present?

      params.merge!(terminated_data: { last_day_worked: user.last_day_worked, eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type },
          is_terminated: true) if custom_table.employment_status? && (user.last_day_worked.present? || user.termination_date.present? || user.termination_type.present?)
      custom_table_user_snapshot = user.custom_table_user_snapshots.new(params)
      custom_snapshots = build_custom_snapshots(user, custom_table, custom_table.custom_table_property, custom_table_user_snapshot, effective_date)

      if custom_table_user_snapshot.ctus_creation.present?
        CustomTableUserSnapshot.bypass_approval = true
        custom_table_user_snapshot.save!
        CustomTableUserSnapshot.bypass_approval = false
        custom_table_user_snapshot.custom_snapshots.create(custom_snapshots)
        ::CustomTables::ManageCustomSnapshotsJob.perform_now(custom_table_user_snapshot) if custom_table_user_snapshot.reload.applied?
      end
    end
  end

  private

  def build_custom_snapshots(employee, custom_table, table_property, custom_table_user_snapshot = nil, effective_date = nil, is_manager_reassigned = false, default_custom_snapshots = nil, lde_data = nil, is_manager_form = nil)
    company = employee.company
    custom_snapshots = []
    if custom_table.role_information? || custom_table.employment_status?
      custom_snapshots = build_preference_fields_snapshots(employee, company, custom_table, table_property, custom_snapshots, custom_table_user_snapshot, default_custom_snapshots, lde_data, is_manager_form)
    end
    custom_snapshots = build_custom_fields_snapshots(employee, company, custom_table, table_property, custom_snapshots, custom_table_user_snapshot, effective_date, is_manager_reassigned, default_custom_snapshots, lde_data, is_manager_form)
    return custom_snapshots
  end

  def build_preference_fields_snapshots(employee, company, custom_table, table_property, custom_snapshots = [], custom_table_user_snapshot = nil, default_custom_snapshots = nil, lde_data = nil, is_manager_form = nil)
    preference_fields = company.prefrences["default_fields"].select { |preference_field| preference_field['profile_setup'] == 'custom_table' && preference_field['custom_table_property'] == table_property }
    preference_fields.each do |preference_field|
      if ['tt', 'td', 'ltw', 'efr'].exclude? preference_field['id']
        custom_field_value = fetch_custom_field_value(employee, preference_field, false, table_property, default_custom_snapshots, lde_data, is_manager_form)
        custom_table_user_snapshot.ctus_creation = true if custom_table_user_snapshot.present? && custom_field_value.present?
        custom_snapshots.push({ preference_field_id: preference_field['id'], custom_field_value: custom_field_value })
      end
    end

    return custom_snapshots
  end

  def build_custom_fields_snapshots(employee, company, custom_table, table_property, custom_snapshots = [], custom_table_user_snapshot = nil, effective_date = nil, is_manager_reassigned = false, default_custom_snapshots = nil, lde_data = nil, is_manager_form = nil)
    custom_fields = custom_table.custom_fields
    custom_fields.each do |custom_field|
      if custom_field.name.downcase == 'effective date' && custom_field.date? && effective_date.present?
        custom_field_value = effective_date
      # elsif (employee.termination_date.present? || is_manager_reassigned.present?) && custom_field.offboarding?.blank? && (custom_field.long_text?.present?)
        # custom_field_value = nil
      else
        custom_field_value = fetch_custom_field_value(employee, custom_field, true, nil, default_custom_snapshots, lde_data, is_manager_form)
        if custom_table_user_snapshot.present? && (custom_field_value.present? || lde_data)
          custom_table_user_snapshot.ctus_creation = true
        end
      end
      custom_snapshots.push({ custom_field_id: custom_field.id, custom_field_value: custom_field_value })
    end
    return custom_snapshots
  end

  def fetch_custom_field_value(employee, profile_field, is_custom_field = false, table_property = '', default_custom_snapshots = nil, lde_data = nil, is_manager_form = nil)
    if default_custom_snapshots && is_manager_form && value_present_in_default_custom_snapshots?(default_custom_snapshots, profile_field, is_custom_field)
      custom_field_data = fetch_custom_field_data(default_custom_snapshots, profile_field)
      return custom_field_data['custom_field_value'] rescue nil
    elsif is_pending_hire_custom_field?(default_custom_snapshots, profile_field)
      return fetch_pendinghire_custom_field_data(default_custom_snapshots, profile_field)
    elsif is_custom_field.present?
      if is_offboarding_custom_field?(default_custom_snapshots, profile_field)
        custom_field_data = fetch_offboarding_custom_field_data(default_custom_snapshots, profile_field)
        return custom_field_data['custom_field_value'] rescue ''
      elsif profile_field.date?
        date_field_value = DateTime.parse(employee.get_custom_field_value_text(profile_field.name, false, nil, nil, true, profile_field.id)) rescue nil
        return date_field_value.strftime("%B %d, %Y") if date_field_value.present?
      elsif lde_data && profile_field.field_type == 'employment_status'
        return lde_data[:emp_status]
      else
        custom_field_value = employee.get_custom_field_value_text(profile_field.name, false, nil, nil, true, profile_field.id, false, true)
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
            return employee.manager_id.try(:to_i)
          when 'jt'
            return employee.title
          when 'dpt'
            return lde_data ? lde_data[:department] : employee.team_id.try(:to_i)
          when 'loc'
            return lde_data ? lde_data[:location] : employee.location_id.try(:to_i)
          else
            return nil
        end
      elsif table_property == 'employment_status'
        if profile_field['id'] == 'st'
          if employee.termination_date.present?
            return 'inactive'
          else
            return employee.state
          end
        elsif profile_field['id'] == 'wp'
          employee.working_pattern_id
        end
      end
    end
  end

  def is_offboarding_custom_field?(default_custom_snapshots, field)
    return false unless default_custom_snapshots.present?

    #return field.employment_status? ? false : true rescue true
    custom_field_data = fetch_offboarding_custom_field_data(default_custom_snapshots, field)
    return custom_field_data.present? ? true : false
  end

  def fetch_offboarding_custom_field_data(default_custom_snapshots, profile_field)
    return default_custom_snapshots.select{ |field| field['custom_field_id'] == profile_field.id}[0] rescue nil
  end

  def is_pending_hire_custom_field? pending_hire, field
    return false unless pending_hire.present? && pending_hire.class.name == 'PendingHire'

    custom_field_data = fetch_pendinghire_custom_field_data(pending_hire, field)
    return custom_field_data.present? ? true : false
  end

  def fetch_pendinghire_custom_field_data pending_hire, profile_field
    profile_field = fetch_pendinghire_custom_field(pending_hire, profile_field)
    if profile_field
      case profile_field[:attribute]
        when 'dpt'
          return pending_hire.team_id&.to_s || nil
        when 'loc'
          return pending_hire.location_id&.to_s || nil
        when 'Employment Status'
          field = CustomField.get_custom_field(pending_hire.company, 'Employment Status')
          return field.custom_field_options.where('option ILIKE ?', profile_field[:new]).take&.id&.to_s || nil
        when 'man'
          return pending_hire.manager_id&.to_s || nil
        else
          return profile_field[:new] || nil
      end
    end
  end

  def fetch_pendinghire_custom_field pending_hire, profile_field
    pending_hire.changed_info.select{ |field| field[:attribute] == profile_field['id'] || field[:attribute] == profile_field['name']}[0] rescue nil
  end

  def does_table_have_offboarding_fields?(custom_table, user)
    if user.offboarding_profile_template_id.present?
      user.offboarding_profile_template.profile_template_custom_field_connections.where(custom_field_id: custom_table.custom_fields.pluck(:id)).count > 0
    else
      custom_table.custom_fields.where(display_location: CustomField.display_locations[:offboarding]).count > 0
    end
  end

  def is_valid_role_information?(custom_table, employee, lde_data)
    return unless lde_data

    custom_table.role_information? && (employee.location_id != lde_data[:location] || employee.team_id != lde_data[:department])
  end

  def fetch_custom_field_data(default_custom_snapshots, profile_field)
    id = profile_field['id'] || profile_field.id
    return default_custom_snapshots.select{ |field| field['custom_field_id'] == id }&.first rescue nil
  end

  def value_present_in_default_custom_snapshots?(default_custom_snapshots, profile_field, is_custom_field)
    id = is_custom_field ? profile_field.id : profile_field['id']
    default_custom_snapshots.any? { |field| field[:custom_field_id] == id }
  end
end
