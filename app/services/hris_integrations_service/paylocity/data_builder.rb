class HrisIntegrationsService::Paylocity::DataBuilder

  attr_reader :parameter_mappings, :company, :integration, :user

  delegate :map_gender, :map_federal_martial_status, :map_home_address, :map_employee_type, 
    :map_pay_frequency, :get_sui_state_value, :get_decimal, :map_status, :get_manager_updation_data, 
    :get_cost_center, :get_effective_date, :map_cost_center_options, :set_autopay_value, :get_phone, to: :helper_service

  delegate :get_user_field_values, :add_custom_sync_field_data, to: :integrations_helper_service

  def initialize(parameter_mappings, company, integration, user)
    @parameter_mappings = parameter_mappings
    @company = company
    @integration = integration
    @user = user
  end

  def build_create_profile_data(add_company_sui_state=false)
    data = {}
    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank?
        data[key] = fetch_data(value, user, integration, 'create', add_company_sui_state, key)
      end
    end
    data
  end

   def build_update_profile_data(updated_attributes)
    data = {}
    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && updated_attributes.include?(value[:name])
        data[key] = fetch_data(value, user, integration, 'update', nil, key)
      end
    end
    data
  end

  private

  def format_date(value)
    return unless value.present?
    value.to_date.strftime('%Y-%m-%d')  
  end

  
  def fetch_data(meta, user, integration, action, add_company_sui_state=false, key)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase
    case field_name 
    when 'user name'
      ( user.id.to_s + (user.first_name[0] + user.last_name).gsub(/[^0-9A-Za-z]/, ''))[0..19]
    when 'status'
      status = action == 'create' ? 'active' : user.state
      map_status(status)
    when 'gender'
      map_gender(user.get_custom_field_value_text(field_name))
    when 'federal marital status'
      map_federal_martial_status(user.get_custom_field_value_text(field_name))
    when 'home phone number', 'mobile phone number'
      get_phone(user.get_custom_field_value_text(field_name))
    when 'line 1', 'line 2', 'city', 'zip', 'state'
      if ['state', 'zip'].include?(field_name)
          home_address_field = user.get_custom_field_value_text('home address', true)
          if home_address_field[:country] == "United States"
            if field_name == 'state'
              state = Country.find_by(name: home_address_field[:country]).states.find_by(name: home_address_field[:state])
              state ? state.key : home_address_field[:state]
            elsif field_name == 'zip'
              home_address_field[:zip]
            end
          end
      else
        user.get_custom_field_value_text('home address', false, field_name.capitalize)
      end
    when 'home address'
      data = user.get_custom_field_value_text(field_name, true)
      data[:personalEmail] = user.personal_email if data.present?
      data[:phone] = get_phone(user.get_custom_field_value_text('home phone number')) if data.present?
      data[:mobilePhone] = get_phone(user.get_custom_field_value_text('mobile phone number')) if data.present?
      data
    when 'department position'
      data = {}
      data[:employeeType] = map_employee_type(user.employee_type_field_option&.option) if user.employee_type_field_option&.option
      data[:jobTitle] = user.title if user.title
      data[:supervisorEmployeeId] = user.manager.paylocity_id if user.manager.present? && user.manager.paylocity_id.present?  
      data[:costCenter1] = cost_center_mapping('costcenter1', data)
      data[:costCenter2] = cost_center_mapping('costcenter2', data)
      data[:costCenter3] = cost_center_mapping('costcenter3', data)
      data
    when 'primary pay rate'
      data = {}
      data[:baseRate] = get_decimal(user.get_custom_field_value_text('baserate'))
      data[:baseRate] = get_decimal(user.get_custom_field_value_text('base rate')) if !data[:baseRate].present?
      data[:salary] = get_decimal(user.get_custom_field_value_text('salary'))
      data[:autoPay] = set_autopay_value(user, 'auto pay')
      data[:payType] = user.get_custom_field_value_text('pay type')
      data[:payFrequency] = map_pay_frequency(user.get_custom_field_value_text('pay frequency'))
      data[:effectiveDate] = format_date(user.start_date)
      data
    when 'primary rate effective data'
      get_effective_date(user, CustomTable.custom_table_properties[:compensation])
    when 'department position effective data'
      get_effective_date(user, CustomTable.custom_table_properties[:role_information])
    when 'title'
      user.title 
    when 'manager id'
      get_manager_updation_data(user, integration, action)
    when 'start date'
      format_date(user.attributes[field_name.tr(' ', '_')])
    when 'employee type'
      map_employee_type(user.employee_type_field_option&.option)
    when 'pay frequency'
      map_pay_frequency(user.get_custom_field_value_text(field_name))
    when 'tax state'
      get_sui_state_value(user.get_custom_field_value_text(field_name, true), user, integration, add_company_sui_state)
    when 'baserate'
      baserate = get_decimal(user.get_custom_field_value_text(field_name))
      get_decimal(user.get_custom_field_value_text('base rate')) if !baserate
    when 'salary'
      get_decimal(user.get_custom_field_value_text(field_name))
    when 'pay type'
      pay_type = user.get_custom_field_value_text(field_name)
      action == 'update' ? {payType: pay_type, autoPay: set_autopay_value(user, 'auto pay')} : pay_type
    when 'tax form'
      tax_form = user.get_custom_field_value_text(field_name)
      tax_form if tax_form && (tax_form == "W2" || tax_form == "1099M" || tax_form == "1099R")
    when 'hire date status'
      format_date(user.start_date)
    when 'company number'
      integration.company_code
    else
      if [:costCenter1, :costCenter2, :costCenter3].include?(key.to_sym) 
        map_cost_center_options(key.to_s.downcase, get_user_field_values(user, meta, field_name), integration)
      elsif [:update_costCenter1, :update_costCenter2, :update_costCenter3].include?(key.to_sym)
        key = key.to_s.downcase.split('update_')[1]
        map_cost_center_options(key, get_user_field_values(user, meta, field_name), integration)
      else
        get_user_field_values(user, meta, field_name)
      end
    end
  end

  def cost_center_mapping(field_name, data)
    value = add_custom_sync_field_data(data, field_name, integration, user, company)
    return map_cost_center_options(field_name, value, integration)
  end

  def helper_service
    HrisIntegrationsService::Paylocity::Helper.new
  end

  def integrations_helper_service
    IntegrationCustomMappingHelper.new
  end

end