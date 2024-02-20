class IntegrationsService::CreateIntegrationUserSnapshots
  include CustomTableSnapshots
  
  attr_reader :company

  def initialize(company)
    @company = company
  end

  def is_approval_required(type)
    approval_required = fetch_custom_table(type).present? ? false : true
  end

  def create_role_info_snapshots(user)
    role_info_table = fetch_custom_table('role_information')
    if role_info_table.present?
      ctus = get_table_applied_ctus(role_info_table, user)
      if ctus.present?
        team_value = ctus.custom_snapshots.find_by(preference_field_id: 'dpt').try(:custom_field_value).try(:to_i)
        manager_value = ctus.custom_snapshots.find_by(preference_field_id: 'man').try(:custom_field_value).try(:to_i)  
        title = ctus.custom_snapshots.find_by(preference_field_id: 'jt').try(:custom_field_value)
        location = ctus.custom_snapshots.find_by(preference_field_id: 'loc').try(:custom_field_value).try(:to_i)
        if team_value != user.team_id || manager_value != user.manager_id || title != user.title || location != user.location_id
          create_user_role_info_ctus(role_info_table, user)
        end
      else
        create_user_role_info_ctus(role_info_table, user)
      end
    end
  end

  def create_employment_status_snapshots(user)
    employment_status_table = fetch_custom_table('employment_status')
    if employment_status_table.present?
      ctus = get_table_applied_ctus(employment_status_table, user)
      if ctus.present?
        employment_status_field = employment_status_table.custom_fields.where(field_type: CustomField.field_types[:employment_status]).take
        user_value = employment_status_field.present? ? fetch_value_text(user, employment_status_field).to_s : nil
        emp_snapshot_value = ctus.custom_snapshots.find_by(custom_field_id: employment_status_field.id).try(:custom_field_value)
       
        status_snapshot_value = ctus.custom_snapshots.find_by(preference_field_id: 'st').try(:custom_field_value)
        if (user_value.present? && user_value != emp_snapshot_value) || (status_snapshot_value != user.state)
          create_user_employment_status_ctus(employment_status_table, user)
        end
      else
        create_user_employment_status_ctus(employment_status_table, user)
      end
    end
  end

  def create_compensation_snapshots(user)
    compensation_table = fetch_custom_table('compensation')
    if compensation_table.present?
      ctus = get_table_applied_ctus(compensation_table, user)
      if ctus.present? 
        create_user_comp_table_ctus(compensation_table, user) if can_create_compensation_ctus(user, compensation_table, ctus).present?
      else
        create_user_comp_table_ctus(compensation_table, user)
      end
    end
  end

  private
   
  def can_create_compensation_ctus(user, compensation_table, ctus)
    pay_freq_field = compensation_table.custom_fields.find_by(name: 'Pay Frequency') 
    pay_rate_field = compensation_table.custom_fields.find_by(name: 'Pay Rate')
    rate_type_field = compensation_table.custom_fields.find_by(name: 'Rate Type')
    
    if pay_freq_field.present?  
      pay_freq_snapshot_value = ctus.custom_snapshots.find_by(custom_field_id: pay_freq_field.id).try(:custom_field_value).to_s  
      user_pay_freq_value = user.custom_field_values.find_by(custom_field_id: pay_freq_field.id).try(:custom_field_option_id).to_s
      return true if pay_freq_snapshot_value != user_pay_freq_value
    end

    if pay_rate_field.present?
      pay_rate_snapshot_value = ctus.custom_snapshots.find_by(custom_field_id: pay_rate_field.id).try(:custom_field_value).to_s
      user_pay_rate_value = user.get_custom_field_value_text(nil, false, nil, pay_rate_field).to_s
      user_pay_rate_value = user_pay_rate_value.gsub(",","|").to_s rescue nil
      return true if pay_rate_snapshot_value != user_pay_rate_value
    end

    if rate_type_field.present?
      rate_type_snapshot_value = ctus.custom_snapshots.find_by(custom_field_id: rate_type_field.id).try(:custom_field_value).to_s 
      user_rate_type_value = user.custom_field_values.find_by(custom_field_id: rate_type_field.id).try(:custom_field_option_id).to_s
      return true if rate_type_snapshot_value != user_rate_type_value
    end

    return false
  end

  def fetch_custom_table(type)
    return @company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[type], is_approval_required: false)
  end


  def get_table_applied_ctus(table, user)
    table.custom_table_user_snapshots.where(state: CustomTableUserSnapshot.states[:applied], user_id: user.id).take
  end

  def set_terminated_params(params, user)
    params.merge!(is_terminated: true, terminated_data: {last_day_worked: user.last_day_worked, eligible_for_rehire: user.eligible_for_rehire, termination_type: user.termination_type})
    
    if user.departed?
      params.merge!(state: 'applied', terminate_callback: true)
    else
      params.merge!( state: 'queue', terminate_job_execution: true)
    end
  end

  def create_user_employment_status_ctus(employment_status_table, user)
    params = {custom_table_id: employment_status_table.id, effective_date: Date.today.strftime("%B %d, %Y"), state: 'queue',  integration_type: CustomTableUserSnapshot.integration_types[:adp_integration], terminate_job_execution: true}
    set_terminated_params(params, user) if user.termination_date.present?
    table_snapshot = user.custom_table_user_snapshots.find_or_initialize_by(custom_table_id: employment_status_table.id, effective_date: Date.today.strftime("%B %d, %Y"), integration_type: CustomTableUserSnapshot.integration_types[:adp_integration])
    table_snapshot.update!(params)
    
    fetch_user_values_for_snapshots(user, employment_status_table).each do |custom_snapshot|
      table_snapshot.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)  
    end
  end

  def create_user_role_info_ctus(role_info_table, user)
    params = {custom_table_id: role_info_table.id, state: 'queue', effective_date: Date.today.strftime("%B %d, %Y"), integration_type: CustomTableUserSnapshot.integration_types[:adp_integration]}
    ctus = user.custom_table_user_snapshots.find_or_initialize_by(params)
    ctus.update(terminate_job_execution: true)
    custom_snapshots = fetch_user_values_for_snapshots(user, role_info_table)
    
    custom_snapshots.each do |custom_snapshot|
      ctus.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)  
    end
  end
  
  def create_user_comp_table_ctus(compensation_table, user)
    params = {custom_table_id: compensation_table.id, effective_date: Date.today.strftime("%B %d, %Y"), state: 'queue',  integration_type: CustomTableUserSnapshot.integration_types[:adp_integration], terminate_job_execution: true}
    ctus = user.custom_table_user_snapshots.create(params)
    custom_snapshots = fetch_user_values_for_snapshots(user, compensation_table)
    custom_snapshots.each do |custom_snapshot|
      ctus.custom_snapshots.find_or_initialize_by(custom_field_id: custom_snapshot[:custom_field_id], preference_field_id: custom_snapshot[:preference_field_id]).update(custom_snapshot)  
    end
  end

  def fetch_user_values_for_snapshots(user, table)
    custom_snapshots_collection = []
    fetch_prefrence_values_for_role_info_table(user, custom_snapshots_collection) if table.role_information?
    fetch_prefrence_values_for_emp_table(user, custom_snapshots_collection) if table.employment_status?
    fetch_user_custom_field_values(user, custom_snapshots_collection, table)

    return custom_snapshots_collection
  end

  def fetch_prefrence_values_for_role_info_table(user, custom_snapshots_collection)
    prefrences = @company.prefrences['default_fields'].select{|field| ['dpt', 'man', 'loc', 'jt'].include? field['id']}
    prefrences.each do |field|
      custom_snapshot = { custom_field_id: nil, preference_field_id: field['id'], custom_field_value: nil}
      case field['id']
      when 'man'
        custom_snapshot[:custom_field_value] = user.manager_id
      when 'loc'
        custom_snapshot[:custom_field_value] = user.location_id
      when 'dpt'
        custom_snapshot[:custom_field_value] = user.team_id
      when 'jt'
        custom_snapshot[:custom_field_value] = user.title
      end

      custom_snapshots_collection.push custom_snapshot
    end
  end

  def fetch_prefrence_values_for_emp_table(user, custom_snapshots_collection)
    custom_field_value = user.state
    custom_field_value = 'inactive' if user.termination_date.present?
    custom_snapshots_collection.push({custom_field_id: nil, preference_field_id: 'st', custom_field_value: custom_field_value})
 end

  def fetch_user_custom_field_values(user, custom_snapshots_collection, table)
    table.custom_fields.each do |field|
      custom_snapshot = {preference_field_id: nil, custom_field_id: field.id}
      custom_field_value = fetch_value_text(user, field)
      
      if field.date?
        custom_snapshot[:custom_field_value] = field.name == 'Effective Date' ? Date.today.strftime("%B %d, %Y") : DateTime.parse(custom_field_value).strftime("%B %d, %Y") rescue nil
      elsif field.employment_status? && user.termination_date.present?
        custom_snapshot[:custom_field_value] = field.custom_field_options.find_by(option: 'Terminated').try(:id)
      elsif field.currency?
        custom_snapshot[:custom_field_value] = custom_field_value.gsub(",", "|")
      elsif field.mcq?
        custom_snapshot[:custom_field_value] = fetch_mcq_field_option_id(user, field)
      else
        custom_snapshot[:custom_field_value] = custom_field_value
      end

      custom_snapshots_collection.push(custom_snapshot) 
    end
  end

  def fetch_value_text(user, field)
    return user.get_custom_field_value_text(field.name, false, nil, nil, true, field.id) if user.present?
  end

  def fetch_mcq_field_option_id(user, field)
    return user.custom_field_values.find_by(custom_field_id: field.id).try(:custom_field_option_id)
  end
end