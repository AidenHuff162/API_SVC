class CustomSections::CustomSectionApprovalManagement
  attr_reader :company, :user_id

  @@default_fields_mapper = {
    access_permission: {name: 'Permission' , pref_id: 'access_permission', attribute: 'user_role_id', is_integer: true, is_profile_attr: false },
    buddy: { name: 'Buddy' , pref_id: 'buddy', attribute: 'buddy_id', is_integer: true, is_profile_attr: false },
    company_email: {name: 'Company Email' , pref_id: 'company_email', attribute: 'email', is_integer: false, is_profile_attr: false },
    about: { name: 'About' , pref_id: 'about', attribute: 'about_you', is_integer: false, is_profile_attr: true },
    twitter: { name: 'Twitter' , pref_id: 'twitter', attribute: 'twitter', is_integer: false, is_profile_attr: true },
    linkedin: { name: 'LinkedIn' , pref_id: 'linkedin', attribute: 'linkedin', is_integer: false, is_profile_attr: true },
    github: {name: 'GitHub' , pref_id: 'github', attribute: 'github', is_integer: false, is_profile_attr: true },
    facebook: {name: 'Facebook' , pref_id: 'facebook', attribute: 'facebook', is_integer: false, is_profile_attr: true },
    department: {name: 'Department' , pref_id: 'department', attribute: 'team_id', is_integer: true, is_profile_attr: false },
    manager: {name: 'Manager' , pref_id: 'manager', attribute: 'manager_id', is_integer: true, is_profile_attr: false },
    location: { name: 'Location' , pref_id: 'location', attribute: 'location_id', is_integer: true, is_profile_attr: false },
    working_pattern: { name: 'Working Pattern' , pref_id: 'working_pattern', attribute: 'working_pattern', is_integer: false, is_profile_attr: false },
    job_title: { name: 'Job Title' , pref_id: 'job_title', attribute: 'title', is_integer: false, is_profile_attr: false },
    status: { name: 'Status' , pref_id: 'status', attribute: 'state', is_integer: false, is_profile_attr: false },
    paylocityid: { name: 'Paylocity ID' , pref_id: 'paylocityid', attribute: 'paylocity_id', is_integer: false, is_profile_attr: false },
    trinetid: { name: 'Trinet ID' , pref_id: 'trinetid', attribute: 'trinet_id', is_integer: false, is_profile_attr: false },
    first_name: { name: 'First Name' , pref_id: 'first_name', attribute: 'first_name', is_integer: false, is_profile_attr: false },
    last_name: { name: 'Last Name' , pref_id: 'last_name', attribute: 'last_name', is_integer: false, is_profile_attr: false },
    preferred_name: { name: 'Prefferred Name' , pref_id: 'preferred_name', attribute: 'preferred_name', is_integer: false, is_profile_attr: false },
    personal_email: { name: 'Personal Email' , pref_id: 'personal_email', attribute: 'personal_email', is_integer: false, is_profile_attr: false },
    start_date: { name: 'Start Date' , pref_id: 'start_date', attribute: 'start_date', is_integer: false, is_profile_attr: false },
    last_day_worked: { name: 'Last Day Worked' , pref_id: 'last_day_worked', attribute: 'last_day_worked', is_integer: false, is_profile_attr: false },
    termination_type: { name: 'Termination Type' , pref_id: 'termination_type', attribute: 'termination_type', is_integer: false, is_profile_attr: false },
    termination_date: { name: 'Termination Date' , pref_id: 'termination_date', attribute: 'termination_date', is_integer: false, is_profile_attr: false },
    eligible_for_rehire: { name: 'Eligible for Rehire' , pref_id: 'eligible_for_rehire', attribute: 'eligible_for_rehire', is_integer: false, is_profile_attr: false }
  }

  def initialize(company, user_id)
    @company = company
    @user = @company.users.find_by(id: user_id)
  end

  def create_custom_section_approval(requester_id, custom_section, fields, updated_approval_chain)
    begin
      custom_section_approval = custom_section.reload.custom_section_approvals.find_or_create_by!(user_id: @user.id, requester_id: requester_id, state: CustomSectionApproval.states[:requested])
      begin
        updated_approval_chain.try(:each) do |chain|
          custom_section_approval.approval_chains.find_or_create_by!(approval_type: chain[:approval_type], approval_ids: chain[:approval_ids])
        end
      rescue Exception => e
        custom_section_approval.destroy!
        return logger.info e.inspect
      end
      
      custom_section_approval.create_cs_approval_chains() if custom_section_approval.custom_section&.is_approval_required.present? && custom_section_approval.requested? && custom_section_approval.requester_id.present?
      
      fields.each do |key, value|
        if ["user_profile","user_role","users"].include?(key)
          is_default_field = true
        else
          is_default_field = false
        end
        create_requested_fields(custom_section_approval, value, is_default_field)
      end
    ensure
      if custom_section_approval.requested_fields.blank?
        custom_section_approval.destroy
        return {}
      end
    end
    custom_section_approval.dispatch_request_change_email
  end

  def create_requested_fields(custom_section_approval, fields, is_default_field)
    fields.try(:each) do |field|
      id = is_default_field ? 'preference_field_id' : 'custom_field_id'
      custom_section_approval.requested_fields.find_or_create_by!({"#{id}": field[id.to_sym], custom_field_value: field[:custom_field_value], field_type: field[:field_type]})
    end
  end

  def prepare_changed_custom_fields(updated_fields, custom_section_id)
    fields = updated_fields[:fields]
    changed_fields = []
    fields.try(:each) do |field|
      field = field[:custom_field]
      if is_custom_field_belongs_to_section?(field, custom_section_id)
        if (field[:field_type] == 'mcq' || field[:field_type] == 'employment_status') && field.key?('custom_field_value') && field[:custom_field_value].key?('custom_field_option_id') && is_mcq_changed?(field[:name], field[:custom_field_value][:custom_field_option_id])
          push_custom_fields(changed_fields, field, {id: field[:custom_field_value][:id], custom_field_option_id: field[:custom_field_value][:custom_field_option_id]})
        elsif field[:field_type] == 'coworker' && field.key?('custom_field_value') && field[:custom_field_value].key?('coworker') && is_coworker_changed?(field[:name], field[:custom_field_value][:coworker_id])
          push_custom_fields(changed_fields, field, {id: field[:custom_field_value][:id], coworker_id: field[:custom_field_value][:coworker_id], coworker: field[:custom_field_value][:coworker]})
        elsif field[:field_type] == 'multi_select' && field.key?('custom_field_value') && field[:custom_field_value].key?('checkbox_values') && is_multi_select_value_changed?(field[:name], field[:custom_field_value][:checkbox_values])
          push_custom_fields(changed_fields, field, {id: field[:custom_field_value][:id], checkbox_values: field[:custom_field_value][:checkbox_values]})
        elsif ['social_security_number', 'social_insurance_number', 'short_text', 'long_text', 'date', 'confirmation', 'number', 'simple_phone'].include?(field[:field_type]) && field.key?('custom_field_value') && field[:custom_field_value].key?('value_text') && is_simple_value_changed?(field[:name], field[:custom_field_value][:value_text])
          push_custom_fields(changed_fields, field, {id: field[:custom_field_value][:id], value_text: field[:custom_field_value][:value_text]})
        elsif ['address', 'currency', 'tax', 'phone', 'national_identifier'].include?(field[:field_type]) && field[:sub_custom_fields].present? && is_sub_custom_field_changed?(field[:name], field[:sub_custom_fields], field[:field_type])
          push_custom_fields(changed_fields, field, {sub_custom_fields: prepare_sub_custom_field(field[:sub_custom_fields])})
        end
      end
    end
    changed_fields
  end

  def push_custom_fields(changed_fields, custom_field, custom_field_value)
    changed_fields.push({custom_field_id: custom_field[:id].to_i, custom_field_value: custom_field_value, field_type: custom_field[:field_type], old_custom_field_value: @user.get_custom_field_value_text(custom_field[:name], true), name: custom_field[:name]})
  end

  def prepare_sub_custom_field(sub_custom_fields)
    sub_custom_fields.try(:each) do |field|
      field[:custom_field_value] = field[:custom_field_value].present? ? {id: field[:custom_field_value][:id], value_text: field[:custom_field_value][:value_text]} : field[:custom_field_value]
    end
    sub_custom_fields
  end

  def is_sub_custom_field_changed?(field_name, new_value, field_type)
    is_parametrize = field_type == 'address' ? false : true
    old_value = @user.get_custom_field_value_text(field_name, true)
    new_value_hash = {}
    new_value.map do |value|
      key = is_parametrize ? value['name']&.downcase&.gsub(" ","_") : value['name']&.downcase&.gsub(" ","")
      new_value_hash.merge!("#{key}": (value[:custom_field_value].present? && value['custom_field_value'].key?('value_text') ? value['custom_field_value']['value_text'] : nil)) 
    end
    return new_value_hash != old_value 
  end

  def is_multi_select_value_changed?(field_name, new_values)
    old_values = @user.get_custom_field_value_text(field_name, false, nil, nil, true)
    return old_values&.sort != new_values&.sort
  end

  def is_mcq_changed?(field_name, new_custom_option_id)
    return new_custom_option_id != @user.get_custom_field_value_text(field_name, false, nil, nil, true)
  end

  def is_coworker_changed?(field_name, new_coworker_id)
    return new_coworker_id != @user.get_custom_field_value_text(field_name, false, nil, nil, true)
  end

  def is_simple_value_changed?(field_name, new_value)
    return @user.get_custom_field_value_text(field_name) != new_value
  end

  def default_fields_changed(updated_user_attributes, custom_section_id)
    custom_section_default_fields = @company.prefrences['default_fields'].map { |field| {api_field_id: field['api_field_id'], field_type: field['field_type']} if field['profile_setup'] == 'profile_fields' && ['user_id', 'profile_photo'].exclude?(field['api_field_id']) && field['custom_section_id'] == custom_section_id }.reject(&:nil?)
    changed_default_fields = []
    custom_section_default_fields.try(:each) do |field|
      case field[:api_field_id]
      when 'access_permission', 'buddy', 'company_email', 'about', 'twitter', 'linkedin', 'github', 'facebook', 'department', 'manager', 'location', 'working_pattern', 'job_title', 'status', 'paylocityid', 'trinetid'
        if updated_user_attributes.key?([@@default_fields_mapper[field[:api_field_id].to_sym][:attribute]].first)
          value = @@default_fields_mapper[field[:api_field_id].to_sym][:is_integer] ? updated_user_attributes[@@default_fields_mapper[field[:api_field_id].to_sym][:attribute]].to_i : updated_user_attributes[@@default_fields_mapper[field[:api_field_id].to_sym][:attribute]]
          old_value = @@default_fields_mapper[field[:api_field_id].to_sym][:is_profile_attr] ? @user.profile[@@default_fields_mapper[field[:api_field_id].to_sym][:attribute]] : @user[@@default_fields_mapper[field[:api_field_id].to_sym][:attribute]]
          push_default_fields(changed_default_fields, field[:api_field_id], value, field[:field_type], old_value, @@default_fields_mapper[field[:api_field_id].to_sym][:is_integer], @@default_fields_mapper[field[:api_field_id].to_sym][:name])
        end
      when 'start_date'
        if updated_user_attributes.key?('start_date')
          date = updated_user_attributes['start_date']
          date = date.in_time_zone(@company.time_zone).to_date
          push_default_fields(changed_default_fields, field[:api_field_id], date, field[:field_type], @user[field[:api_field_id]].to_date, @@default_fields_mapper[field[:api_field_id].to_sym][:name])
        end
      else
        push_default_fields(changed_default_fields, field[:api_field_id], updated_user_attributes[field[:api_field_id]], field[:field_type], @user[field[:api_field_id]], @@default_fields_mapper[field[:api_field_id].to_sym][:name]) if updated_user_attributes.key?([field[:api_field_id]].first)
      end
    end
    changed_default_fields
  end

  def push_default_fields(changed_default_fields, pref_id, new_value, field_type, old_value, is_integer = false, field_name)
    new_value = nil if new_value == 0 && pref_id != 'access_permission'
    if new_value != old_value
      value_by_name = get_location_department_name(pref_id, new_value, old_value) if ['location', 'department'].include?(pref_id) 
      changed_default_fields.push({preference_field_id: pref_id, custom_field_value: new_value, field_type: field_type, old_custom_field_value: old_value, name: field_name, value_by_name: value_by_name})
    end
  end

  def is_custom_field_belongs_to_section?(updated_custom_field, custom_section_id)
    return false if updated_custom_field['id'].to_i == 0
    
    custom_field = @company.custom_fields.find_by(id: updated_custom_field['id'].to_i)
    return custom_field.present? && custom_field.custom_section_id == custom_section_id
  end

  def trigger_profile_approval_request(current_user_id, custom_section_id, changed_fields, updated_approval_chain)
    custom_section = @company.custom_sections.find_by_id(custom_section_id)
    create_custom_section_approval(current_user_id, custom_section, changed_fields, updated_approval_chain[:approval_chains])
  end

  def get_location_department_name(pref_id, new_value, old_value)
    value_by_names = {}
    value_by_names[:new_value] = get_field_name(pref_id, new_value) if new_value
    value_by_names[:old_value] = get_field_name(pref_id, old_value) if old_value
    value_by_names
  end

  def get_field_name(pref_id, value)
    pref_id = 'team' if pref_id == 'department' 
    pref_id.capitalize.constantize.get_name(value, @company.id)
  end
end
