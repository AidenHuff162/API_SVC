class HrisIntegrationsService::Workday::Helper

  def conflicted_custom_field_mapper
    {
      ethnicity: 'race/ethnicity',
      company_entity: 'company/entity',
      marital_status: 'federal marital status',
      shipping_address: 'shipping address (for packages/swag items)'
    }
  end

  def custom_field_mapper(field_name)
    conflicted_custom_field_mapper[field_name] || field_name.to_s.downcase
  end

  def sub_custom_field_mapper
    {
      address: {
        line1: 'Line 1', line2: 'Line 2', state: 'State',
        country: 'Country', city: 'City', zip: 'Zip'
      },
      phone: { country_alpha3: 'Country', area_code: 'Area code', phone: 'Phone' },
      national_id: { id_country: 'ID Country', id_type: 'ID Type', id_number: 'ID Number' }
    }
  end

  def onboarding_stages
    %w[pre_start first_week first_month registered ramping_up]
  end

  def termination_stages
    %w[last_month last_week offboarding departed]
  end

  def get_current_stage(user)
    (user.termination_date.blank? ? onboarding_stages : termination_stages).each do |stage|
      return User.current_stages[stage] if user.send("if_#{stage}?")
    end
  end

  def manage_user_current_stage(user)
    user.update!(current_stage: get_current_stage(user), skip_org_chart_callback: true)
  end

  def create_custom_field_options(company, params)
    %i[cost_center company_entity vertical].each do |option|
      CustomFieldOption.create_custom_field_option(company, custom_field_mapper(option).titleize, params[option]) if params.key?(option)
    end
  end

  def workday_custom_fields
    %i[date_of_birth gender marital_status citizenship_country citizenship_type disability employment_status ethnicity military_service
       emergency_contact_name emergency_contact_relationship cost_center company_entity vertical nationality middle_name] # .push(sub_division division)
  end

  def manage_custom_field_data(user, params)
    return if params.blank?

    custom_field_args = [nil, true, nil, false, false, true]
    sub_custom_field_args = [nil, false, false, true]
    workday_custom_fields.each do |field|
      params[field].present? && CustomFieldValue.set_custom_field_value(user, custom_field_mapper(field).titleize, params[field], *custom_field_args)
    end

    %i[home_address shipping_address mobile_phone_number home_phone_number emergency_contact_number national_id].each do |field|
      next if params[field].blank?

      field_name, field_data = get_field_names_with_data(field)
      if params[field].is_a?(Hash)
        field_data.each { |data| CustomFieldValue.set_custom_field_value(user, custom_field_mapper(field).titleize(keep_id_suffix: true), params[field][data], sub_custom_field_mapper[field_name][data], false, *sub_custom_field_args) }
      else
        CustomFieldValue.set_custom_field_value(user, custom_field_mapper(field).titleize, params[field], *custom_field_args)
      end
    end
  end

  def get_field_names_with_data(field)
    case field
    when :shipping_address, :home_address
      [:address, %i[line1 line2 city zip state country]]
    when :mobile_phone_number, :home_phone_number, :emergency_contact_number
      [:phone, %i[country_alpha3 area_code phone]]
    when :national_id
      [:national_id, %i[id_country id_type id_number]]
    else
      []
    end
  end

  def workers_hash(data)
    convert_to_array(data.dig(:get_workers_response, :response_data, :worker))
  end

  def convert_to_array(data)
    return [] if data.blank?
    return [data] if data.is_a?(Hash)
    data
  end

  def manage_employee_type(user, option)
    return if (custom_field = get_employee_type_field(user.company)).blank?

    type = CustomFieldOption.get_custom_field_option(custom_field, option) || custom_field.custom_field_options.create(option: option)
    user.set_employee_type_field_option(type.id)
  end

  def get_employee_type_field(company)
    attrs = { field_type: CustomField.field_types[:employment_status], custom_table_id: CustomTable.employment_status(company.id) }
    company.custom_fields.find_by(attrs)
  end

  def manage_custom_tables(user, sapling_params)
    custom_table_service = IntegrationsService::ManageIntegrationCustomTables.new(user.company, nil, 'workday')
    custom_table_service.manage_role_information_custom_table(user, sapling_params) if should_create_role_info?(user)
  end

  def should_create_role_info?(user)
    user.last_day_worked.present? ? user.last_day_worked >= Date.today : user.active?
  end

  def user_cf_params_hash(user_params, custom_field_params)
    { user: user_params, custom_field: custom_field_params }
  end

  def manage_user_on_create_update(user, user_params, custom_field_params)
    create_custom_field_options(user.company, custom_field_params)
    manage_custom_field_data(user, custom_field_params)
    manage_employee_type(user, custom_field_params[:employment_status]) if termination_stages.exclude?(user.current_stage)
    manage_custom_tables(user, user_cf_params_hash(user_params, custom_field_params))
  end

  def get_request_type(operation_name)
    case operation_name
    when 'worker_document', 'external_form_i_9', 'external_disability_self_identification_record'
      'put'
    when 'worker_additional_data'
      'edit'
    when 'contact_information'
      'maintain'
    else
      'change'
    end
  end

  def workday_operation_name(operation_name)
    "#{get_request_type(operation_name)}_#{operation_name}"
  end

  def get_manager_from_org(worker_organization_data)
    manager_id = nil
    worker_organization_data.each do |wod|
      next unless (org_data = wod[:organization_data]).present? && (org_data.dig(:organization_type_reference, :id)&.second) == 'Supervisory'

      org_support_roles = org_data.dig(:organization_support_role_data, :organization_support_role)
      org_support_roles.each do |org_support_role|
        org_role_ref = org_support_role.dig(:organization_role_reference, :id)&.second
        next unless org_role_ref == 'Manager'

        manager_id = org_support_role.dig(:organization_role_data, :worker_reference, :id)&.second
      end
    end

    manager_id
  end

  def get_worker_subtype_filters(company, worker_type)
    integration = company.get_integration('workday')
    filter_name = "#{worker_type == 'Employee_ID' ? 'Employee' : 'Contingent'} Worker Filter"
    integration.integration_credentials.by_name(filter_name).take.selected_options || []
  end

end
