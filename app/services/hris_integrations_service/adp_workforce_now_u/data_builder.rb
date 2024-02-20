class HrisIntegrationsService::AdpWorkforceNowU::DataBuilder
  include HrisIntegrationsService::AdpWorkforceNowU::AdpFieldsValidator
  include HrisIntegrationsService::AdpWorkforceNowU::AdpAddressFieldsValidator

  attr_reader :enviornment

  delegate :initialize_identification_name_and_code, :format_phone_number, :format_address, 
  :format_currency, :manage_itin_field_data, :fetch_template_value, :fetch_adp_manager_position_id,
  :fetch_company_code_based_code_value, :get_preference_field_data, :get_default_fields_array, :fetch_enviornment_based_code_value,
  :fetch_department_code_value, :build_race_ethnicity_data, :build_update_race_params, :create_loggings, to: :helper_service

  def initialize(enviornment)
    @enviornment = enviornment
  end

  def build_applicant_onboard_data(user, adp_wfn_api = nil, access_token=nil, certificate=nil, version=nil)
    if user.company.sync_template_fields_feature_flag
      data = {}
      data = add_default_fields_data(data, user)
    else
      data = {
      first_name: user.first_name,
      last_name: user.last_name,
      start_date: user.start_date.to_s,
      preferred_name: validate_name(user.preferred_name),
      personal_email: validate_email(user.personal_email),
      company_email: validate_email(user.email),
      job_title: fetch_enviornment_based_code_value(user.title, user.company_id, enviornment, 'JobTitle')
      }
    end

    identification = {}
    if adp_wfn_api.present? && adp_wfn_api.enable_tax_type
      identification = validate_tax_values(user.get_custom_field_value_text_by_profile_template_check('Tax', true))
      identification[:tax_type] = '' if identification && identification[:tax_value].nil?
    else
      identification = initialize_identification_name_and_code(enviornment)
      identification[:tax_value] = user.get_custom_field_value_text_by_profile_template_check(identification[:name])
      identification = validate_tax_values(user.get_custom_field_value_text_by_profile_template_check('Tax', true)) if identification[:tax_value].blank?
      identification[:tax_value] = ["SSN", "SIN"].include?(identification[:tax_type]) ? identification[:tax_value] : '' if identification.present?
    end

    if identification.present?
      data[:identification_number] =  identification[:tax_type] =='ITIN' ? validate_itin_value(manage_itin_field_data(identification[:tax_value])) : identification[:tax_value].to_s.gsub('-', '')
      data[:identification_code] = identification[:tax_type]
      data[:country_code] = 'US' if identification[:tax_type] == 'NID'
      data[:sin_expiry_date] = data[:identification_code].eql?('SIN') && data[:identification_number]&.slice(0)&.eql?('9') ? validate_date(user.get_custom_field_value_text_by_profile_template_check('SIN Expiry Date').to_s) : nil
    end

    data[:middle_name] = validate_name(user.get_custom_field_value_text_by_profile_template_check('Middle Name'))
    data[:date_of_birth] = validate_date(user.get_custom_field_value_text_by_profile_template_check('Date of Birth'))
    
    data[:federal_marital_status] = validate_marital_status(user.get_custom_field_value_adp_code('Federal Marital Status', enviornment))
    data[:gender] = validate_gender(user.get_custom_field_value_adp_code('Gender', enviornment) || 'N')

    data[:employment_status] = user.get_custom_field_value_adp_code('Employment Status', enviornment)
    data[:business_unit] = user.get_custom_field_value_adp_code('Business Unit', enviornment)
    data[:pay_frequency] = user.get_custom_field_value_adp_code('Pay Frequency', enviornment)
    data[:rate_type] = user.get_custom_field_value_adp_code('Rate Type', enviornment)

    data[:home_address] = validate_address(format_address(user.get_custom_field_value_text_by_profile_template_check('Home Address', true), version, enviornment))
    data[:home_phone_number] = validate_phone(format_phone_number(user.get_custom_field_value_text_by_profile_template_check('Home Phone Number', true)))
    data[:mobile_phone_number] = validate_phone(format_phone_number(user.get_custom_field_value_text_by_profile_template_check('Mobile Phone Number', true)))
    data[:pay_rate] = format_currency(user.get_custom_field_value_text_by_profile_template_check('Pay Rate', true))

    if version == 'v2'
      data[:onboarding_template] = fetch_template_value(adp_wfn_api, user.adp_onboarding_template, enviornment, version)
      if(data[:onboarding_template].blank?) 
        create_loggings(user.company, "ADP Workforce Now - #{enviornment}", 401, 'Onboarding Template Code is required error', {user_adp_template: user.adp_onboarding_template, user_id: user.id}) 
      end
    end
    
    data[:worked_in_country] = user.get_custom_field_value_text_by_profile_template_check('Worked in Country') if version == 'v2'

    data[:company_code] = user.get_custom_field_value_adp_code('ADP Company Code', enviornment) if adp_wfn_api&.enable_company_code.present?
    
    if user.manager.present? && user.manager.start_date < user.start_date && version == 'v2'
      data[:manager_adp_position_id] = fetch_adp_manager_position_id(user.company, user.manager, enviornment, access_token, certificate) rescue nil
    end

    # if adp_wfn_api&.enable_company_code.present? && data[:company_code].present?
    #   data[:department] = fetch_company_code_based_code_value('team', user, data[:company_code], access_token, certificate)
    #   data[:location] = fetch_company_code_based_code_value('location', user, data[:company_code], access_token, certificate)
    # else
    data[:department] = fetch_department_code_value(user.team, user.company.id, data[:company_code], enviornment)
    data[:location] = fetch_enviornment_based_code_value(user.location, user.company.id, enviornment, nil, true)
    # end

    data = build_race_ethnicity_data(data, user, enviornment, version)
    data
  end

  def build_change_personal_communication_email_data(value, user)
    data = {
      personal_email: (value || user.personal_email),
      associate_id: fetch_enviornment_based_user_id(user)
    }
  end

  def build_change_business_communication_email_data(value, user)
    data = {
      company_email: (value || user.personal_email),
      associate_id: fetch_enviornment_based_user_id(user)
    }
  end

  def build_change_middle_name_data(value, user)
    data = {
      first_name: user.first_name,
      last_name: user.last_name,
      middle_name: user.get_custom_field_value_text_by_profile_template_check('Middle Name'),
      associate_id: fetch_enviornment_based_user_id(user)
    }
  end

  def build_change_preferred_name_data(value, user)
    data = {
      associate_id: fetch_enviornment_based_user_id(user),
      preferred_name: (value || user.preferred_name)
    }
  end

  def build_change_marital_status_data(user)
    data = {
      associate_id: fetch_enviornment_based_user_id(user),
      federal_marital_status: user.get_custom_field_value_adp_code('Federal Marital Status', enviornment)
    }
  end

  def build_change_legal_address_data(user)
    data = {
      home_address: format_address(user.get_custom_field_value_text('Home Address', true)),
      associate_id: fetch_enviornment_based_user_id(user),
    }
  end

  def build_change_personal_communication_landline_data(user)
    data = {
      home_phone_number: format_phone_number(user.get_custom_field_value_text('Home Phone Number', true)),
      associate_id: fetch_enviornment_based_user_id(user),
    }
  end

  def build_change_personal_communication_mobile_data(user)
    data = {
      mobile_phone_number: format_phone_number(user.get_custom_field_value_text('Mobile Phone Number', true)),
      associate_id: fetch_enviornment_based_user_id(user),
    }
  end

  def build_change_base_remunration_data(user)
    data = {
      work_assignment_id: user.adp_work_assignment_id,
      associate_id: fetch_enviornment_based_user_id(user),
      event_reason_code: 'OTH',
      rate_type: user.get_custom_field_value_adp_code('Rate Type', enviornment),
      pay_rate: format_currency(user.get_custom_field_value_text('Pay Rate', true)),
      effective_date: Date.today.strftime("%Y-%m-%d")
    }
  end

  def build_change_ethnicity_data(user)
    race_id_method, race_code_value = build_update_race_params(user, enviornment)
    data = {
      race_id_method: race_id_method,
      ethnicity: race_code_value,
      associate_id: fetch_enviornment_based_user_id(user)
    }
  end

  def build_change_manager_data(user, manager_id)
    data = {
      effective_date: Date.today.strftime("%Y-%m-%d"),
      work_assignment_id: user.adp_work_assignment_id,
      manager_adp_position_id: manager_id,
      associate_id: fetch_enviornment_based_user_id(user)
    }

  end

  def build_change_string_custom_field_data(user, params)
    {
      associate_id: fetch_enviornment_based_user_id(user),
      adp_string_value: params[:adp_string_value],
      adp_item_id: params[:adp_item_id],
      adp_short_name: params[:adp_short_name]
    }
  end

  def build_terminate_employee_data(value)
    data = {
      termination_date: fetch_termination_date(value),
      last_worked_date: fetch_last_day_worked(value),
      rehire_eligible_indicator: true,
      severance_eligible_indicator: true,
      reason_code: 'A'
    }
  end

  def build_rehire_employee_data(user, position_id)
    data = {
      associate_id: fetch_enviornment_based_user_id(user),
      position_id: position_id,
      effective_date: fetch_start_date(user),
      rehire_date: fetch_start_date(user),
      reason_code: 'CURR'
    }
  end

  private

  def fetch_start_date(object)
    return object.start_date.strftime('%Y-%m-%d') if object.start_date
    Date.today.in_time_zone(object.company.time_zone).strftime('%Y-%m-%d')
  end

  def fetch_enviornment_based_user_id(object)
     enviornment == 'US' ? object.adp_wfn_us_id : object.adp_wfn_can_id
  end

  def fetch_termination_date(object)
    object[:termination_date].present? ? object[:termination_date] : Date.today.strftime('%Y-%m-%d')
  end

  def fetch_last_day_worked(object)
    object[:last_day_worked].present? ? object[:last_day_worked] : Date.today.strftime('%Y-%m-%d')
  end

  def helper_service
    HrisIntegrationsService::AdpWorkforceNowU::Helper.new
  end

  def add_default_fields_data(data, user)
    fields_present_in_template = user.onboarding_profile_template.profile_template_custom_field_connections.where.not(default_field_id: nil).pluck(:default_field_id) if (user.onboarding_profile_template)
    get_default_fields_array().each do |field|
      data[field[:params_key]] = get_preference_field_data(field[:params_key], user, enviornment) if (user.onboarding_profile_template.nil? || fields_present_in_template.include?(field[:default_field_id]))
    end

    data.deep_symbolize_keys!
  end

end