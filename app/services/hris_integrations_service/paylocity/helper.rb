class HrisIntegrationsService::Paylocity::Helper
  def fetch_integration(company, user=nil)
    if user.present?
      company.integration_instances.where(api_identifier: 'paylocity').find_each do |instance|
        return instance if can_integrate_profile?(instance, user)
      end
    else
      company.integration_instances.where(api_identifier: 'paylocity')  
    end
  end
 
  def is_integration_valid?(integration)
    integration.present? && integration.company_code.present? && integration.integration_type.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def create_loggings(company, action, status, request='No Request', response = {})
    LoggingService::IntegrationLogging.new.create(
      company,
      'Paylocity',
      action,
      request,
      response,
      status
    )
  end

  def notify_slack(message)
    ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
      IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
  end

  def send_notifications(user)
    message = I18n.t("history_notifications.hris_sent", name: user.full_name, hris: "Paylocity")
    History.create_history({
      company: user.company,
      user_id: user.id,
      description: message,
      attached_users: [user.id],
      created_by: History.created_bies[:system],
      event_type: History.event_types[:integration]
    })

    SlackNotificationJob.perform_later(user.company.id, {
      username: user.full_name,
      text: message
    })
  end

  def apply_to_location?(filter, user)
    location_ids = filter['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filter, user)
    team_ids = filter['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filter, user)
    employee_types = filter['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end
  
  def log_statistics(action, company)
    if action == 'success'
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end

  def map_gender(value)
    case value.downcase
    when 'male'
      'M'
    when 'female'
      'F'
    else
      'M'
    end if value
  end

  def map_federal_martial_status(value)
    case value.downcase
    when 'single'
      'S'
    when 'married filing jointly', 'married filing separately'
      'M'
    when 'qualifying widow(er) with dependent child'
      'W'
    end if value
  end

  def map_home_address(home_address_field)
    data = {}
    
    if home_address_field
      data[:address1] = home_address_field[:line1][0..39] if home_address_field[:line1]
      data[:address2] = home_address_field[:line2][0..39] if home_address_field[:line2]
      data[:city] = home_address_field[:city] if home_address_field[:city]
      if home_address_field[:state] && home_address_field[:country] == "United States"
        state = Country.find_by(name: home_address_field[:country]).states.find_by(name: home_address_field[:state])
        data[:state] = state ? state.key : home_address_field[:state]
      end
      data[:zip] = home_address_field[:zip] if home_address_field[:zip] && home_address_field[:country] == "United States"
    end

    data
  end

  def map_employee_type(employee_type)
    case employee_type.gsub(' ' , '_').downcase
    when "full_time"
      'RFT'
    when "part_time"
      'RPT'
    when "temporary"
      'TFT'
    when "contract"
      'SNL'
    end if employee_type
  end

  def map_pay_frequency(pay_frequency)
    case pay_frequency.downcase
    when 'annual'
      'A'
    when 'bi-weekly'
      'B'
    when 'daily'
      'D'
    when 'monthly'
      'M'
    when 'semi-monthly'
      'S'
    when 'quarterly'
      'Q'
    when 'weekly'
      'W'
    end if pay_frequency
  end

  def get_sui_state_value(user_tax_state, user, integration, add_company_sui_state=false)
    sui_state = State.find_by(name: user_tax_state)&.key if user_tax_state
    tax_form = user.get_custom_field_value_text('tax form')
    if tax_form == "W2"
      if !sui_state
        home_address_field = user.get_custom_field_value_text('home address', true)
        state = State.find_by(name: home_address_field[:state])
        state = home_address_field[:country] && home_address_field[:country] != "United States" ? state&.key : home_address_field[:state]
        state = add_company_sui_state ? integration.sui_state : state
        sui_state = state ? state : integration.sui_state
      end
    end

    sui_state
  end

  def get_decimal(val)
    val = val.gsub(/[^\d\.]/, '') rescue nil
    val.length > 0 ? val.to_f : nil rescue nil
  end

  def map_status(val)
    val.downcase == 'active' ? 'A' : 'T'
  end

  def get_manager_updation_data(user, integration, action)
    data = {}
    supervisorid = user.manager.paylocity_id rescue nil
    
    if supervisorid.present?
      data[:supervisorEmployeeId] = supervisorid
      data[:reviewerEmployeeId] = supervisorid
      data[:supervisorCompanyNumber] = integration.company_code
      data[:effectiveDate] = Date.tomorrow.strftime("%Y-%m-%d") 
      data[:changeReason] = 'Change Supervisor'
      data[:isSupervisorReviewer] = "true"
    elsif !user.manager
      data[:supervisorEmployeeId] = "~"
      data[:reviewerEmployeeId] = ""
      data[:supervisorCompanyNumber] = "~"
      data[:effectiveDate] = Date.today.strftime("%Y-%m-%d")
      data[:changeReason] = 'Change Supervisor'
    end

    data
  end

  def get_phone(phone)
    phone = phone[1..-1] if phone.present? && phone.start_with?("'+")
    phone
  end

  def map_sapling_state(val)
    val == 'A' ? 'active' : nil
  end

  def map_sapling_gender(val)
    case val
    when 'M'
      'Male'
    when 'F'
      'Female'
    else
      'Male'
    end
  end

  def map_sapling_marital_status(val)
    case val
    when 'S'
      'Single'
    when 'M'
      'Married filing jointly'
    when 'M'
      'Married filing separately'
    when 'W'
      'Qualifying widow(er) with dependent child'
    end
  end

  def map_sapling_employee_type(val)
    case val
    when "RFT"
      'Full Time'
    when "RPT"
      'Part Time'
    when "TFT"
      'Temporary'
    when "SNL"
      'Contract'
    end
  end

  def map_sapling_pay_frequency(pay_frequency)
    case pay_frequency
    when 'A' 
      'Annual'
    when 'B'
      'Bi-weekly'
    when 'D'
      'Daily'
    when 'M' 
      'Monthly'
    when 'S' 
      'Semi-Monthly'
    when 'Q' 
      'Quarterly'
    when 'W'
      'Weekly'
    end 
  end

  def map_sapling_manager(value, user)
    new_manager = user.company.users.where(paylocity_id: value).first
    if user.present? && new_manager.present? && user.manager_id != new_manager.id
      user.flush_managed_user_count(user.manager_id, new_manager.id)
      return new_manager.id
    end
  end

  def get_cost_center(user, field_name)
    user.get_custom_field_value_text(field_name,false, nil, nil, false, nil,false,false,false,false, nil, false ,false, true)
  end

  def map_sapling_cost_center(field_name, value, integration)
    field_value = nil
    cost_center_credential = integration.integration_credentials.find_by(name: field_name)
    cost_center_credential&.dropdown_options&.each do |key, option|
      if option['option'] == value
        field_value = option['name']
        break
      end
    end
    field_value
  end

  def map_cost_center_options(field_name, value, integration)
    return nil if value.blank?
    value = value.downcase.parameterize.underscore
    cost_center_credential = integration.integration_credentials.find_by(name: field_name)
    return nil if !cost_center_credential.dropdown_options || ['', nil].include?(cost_center_credential.dropdown_options["#{value}"])
    cost_center_credential.dropdown_options["#{value}"]['option']
  end

  def get_effective_date(user, table_type)
    table = user.company.custom_tables.find_by(custom_table_property: table_type)
    return unless table.present?

    ctus = user.custom_table_user_snapshots.where(state: :applied, custom_table_id: table.id).take
    return unless ctus.present?
    
    field = table.custom_fields.find_by(name: 'Effective Date')

    return unless field.present?

    return ctus.custom_snapshots.where(custom_field_id: field.id).take.try(:custom_field_value).to_s
  end

  def set_autopay_value(user, field_name)
    auto_pay = map_auto_pay_value(user.get_custom_field_value_text(field_name))
    if auto_pay.nil?
      auto_pay = user.get_custom_field_value_text('pay type') == 'Salary' ? true : false
    end
    auto_pay
  end

  def map_auto_pay_value(value)
    bool_hash = {"true": true, "false": false}
    bool_hash[value&.downcase&.to_sym]
  end

  def map_change_reason(params)
    params&.deep_symbolize_keys!
    if params.keys.include?(:departmentPosition) && !params[:departmentPosition].first&.blank? && !params[:departmentPosition].first[:changeReason].present?
      params[:departmentPosition].first.merge!(changeReason: 'Position Change')
    end
    params
  end
end