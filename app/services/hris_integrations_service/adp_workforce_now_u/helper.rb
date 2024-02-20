class HrisIntegrationsService::AdpWorkforceNowU::Helper
  include HrisIntegrationsService::AdpWorkforceNowU::AdpFieldsValidator

  NULLIFY_METHODS_HASH = {
    'Home Phone is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :communication, :landlines, 0],
    'Personal Mobile is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :communication, :mobiles, 0],
    'Job Title is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :job],
    'Home Department is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :homeOrganizationalUnits, 1, :nameCode],
    'Business Unit is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :homeOrganizationalUnits, 0, :nameCode],
    'Ethnicity / Race ID Method is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :raceCode],
    'Ethnicity is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :ethnicityCode],
    'Marital Status is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :maritalStatusCode],
    'Gender is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :genderCode],
    'Tax ID Type is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :governmentIDs, 0, :nameCode],
    'Pay Frequency is invalid.': [:applicantOnboarding, :applicantPayrollProfile, :payCycleCode],
    'Location is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :homeWorkLocation],
    'Worker Category is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :workerTypeCode],
    'Reports To is invalid.': [:applicantOnboarding, :applicantWorkerProfile, :reportsTo],
    'Legal Address State/Province/Territory is invalid.': [:applicantOnboarding, :applicantPersonalProfile, :legalAddress]
  }

  def initialize_adp_wfn_us(company)
    return unless company.present?
    company.integration_instances.where(api_identifier: 'adp_wfn_us', state: :active).take
  end

  def initialize_adp_wfn_can(company)
    return unless company.present?
    company.integration_instances.where(api_identifier: 'adp_wfn_can', state: :active).take  
  end

  def can_integrate_profile?(adp_wfn_api, user)
    return false unless adp_wfn_api.present? && adp_wfn_api.filters.present?
    filters = adp_wfn_api.filters

    (apply_to_location?(filters, user) && apply_to_team?(filters, user) && apply_to_employee_type?(filters, user))
  end

  def create_loggings(company, integration_name, state, action, result, api_request = 'No Request')
    LoggingService::IntegrationLogging.new.create(
      company,
      integration_name,
      action,
      api_request,
      result,
      state.to_s
    )
  end

  def notify_slack(message)
    ::IntegrationErrors::SendIntegrationErrorNotificationToSlackJob.perform_now(message,
      IntegrationErrorSlackWebhook.integration_types.key(IntegrationErrorSlackWebhook.integration_types[:human_resource_information_system]))
  end

  def initialize_identification_name_and_code(enviornment)
    data = {}
    if enviornment == 'US'
      data[:name] = 'Social Security Number'
      data[:tax_type] = 'SSN'
    elsif enviornment == 'CAN'
      data[:name] = 'Social Insurance Number'
      data[:tax_type] = 'SIN'
    end
  
    data
  end

  def manage_itin_field_data tax_value
    if tax_value.present? && tax_value.length == 9
      tax_value = tax_value.insert(3,'-')
      tax_value = tax_value.insert(6,'-')
    end
  end

  def format_phone_number(data)
    return {} unless data.present?
    formatted_data = parse_phone_number(data) || {}

     formatted_data[:area_dialing] = formatted_data[:area_code]
    formatted_data[:country_dialing] = fetch_dialing_code((formatted_data[:country_alpha3] || formatted_data[:country]))
    formatted_data[:access] = fetch_national_prefix((formatted_data[:country_alpha3] || formatted_data[:country]))
    formatted_data[:dial_number] = formatted_data[:phone]

     formatted_data
  end

   def format_address(data, version = 'v1', enviornment = 'US')
    return {} unless (data.present? || data.is_a?(Hash))

    formatted_data = data

    if version == 'v2'
      limit = enviornment == 'CAN' ? 19 : 29
      formatted_data[:line1] = fetch_line_data(formatted_data[:line1], limit) 
      formatted_data[:line2] = fetch_line_data(formatted_data[:line2], limit)
    end

    formatted_data[:line1] = format_address_lines(formatted_data[:line1]) if formatted_data[:line1] 
    formatted_data[:line2] = format_address_lines(formatted_data[:line2]) if formatted_data[:line2]

    formatted_data[:city_name] = formatted_data[:city]
    formatted_data[:country_code] = fetch_adp_country_code_by_name(formatted_data[:country])
    formatted_data[:postal_code] = formatted_data[:zip]

    country_subdivission_level = nil
    state = fetch_state(formatted_data[:country], formatted_data[:state])
    if formatted_data[:country_code].present? && ['US', 'CA'].include?(formatted_data[:country_code])
      country_subdivission_level = state&.key
    else
      country_subdivission_level = state&.state_codes.present? ? state.state_codes['adp_state_code'] : state&.name
    end
    formatted_data[:country_subdivission_level] = country_subdivission_level

    formatted_data
  end

  def format_address_lines(str)
    #removes diactrical marks, -> restricted special character, -> consecutive duplicate special chrs
    data = str = ((ActiveSupport::Inflector.transliterate(str)).gsub(/[^a-zA-Z0-9\- #,.\/()]/,"")).squeeze(" #,'-./()")
    data = remove_consecutive_special_characters(data) while !data.match?("^(?!.*[ '.,/#]{2}).*$") rescue str #removes consecutive different special chrs
    data.strip
  end


  def remove_consecutive_special_characters(data)
    split_data, special_chars_allowed_array = data.split(''), ['-', ' ', '/', ',', "'", '#', '(', ')', '.'].freeze
    split_data.each.with_index do |chr, indx|
      (split_data[indx+1] = '' if special_chars_allowed_array.include?(split_data[indx..indx+1].first) && special_chars_allowed_array.include?(split_data[indx..indx+1].last)) if indx + 1 != split_data.length
    end
    split_data.join()
  end

  def fetch_line_data(data, limit); data.to_s&.length > limit ? trim_address_length(data, limit) : data end
  def trim_address_length(data, limit); data[0..limit] if data && data.class == String end

  def format_sapling_phone_number(data)
    phone_number = data['countryDialing'].to_s + data['areaDialing'].to_s + data['dialNumber'].to_s
    formatted_data = {}
    alpha3 = nil

    if data['countryDialing'].present?
      alpha2 = Phonelib.parse(phone_number)&.country rescue nil
      if alpha2.present?
        alpha3 = ISO3166::Country.find_country_by_alpha2(alpha2).alpha3 rescue nil
      end
      if alpha3.blank?
        alpha3 = ISO3166::Country.find_country_by_country_code(data['countryDialing']).alpha3 rescue nil
      end
    end

    formatted_data[:country_dialing] = alpha3.blank? ? 'USA' : alpha3
    formatted_data[:area_dialing] = data['areaDialing']
    formatted_data[:dial_number] = data['dialNumber']

    formatted_data
  end

  def format_sapling_address(data)
    formatted_data = {}

    formatted_data[:line1] = data['lineOne']
    formatted_data[:line2] = data['lineTwo']
    formatted_data[:city] = data['cityName']
    formatted_data[:zip] = data['postalCode']
    formatted_data[:state] = data['countrySubdivisionLevel1']['codeValue'] rescue nil
    formatted_data[:country] = fetch_country(data['countryCode'])&.name

    formatted_data
  end

   def format_currency(data)
    return {} unless data.present?
    data.is_a?(Hash) ? data : { currency_type: nil, currency_value: data }
  end

   def parse_phone_number(data)
    return data unless data.is_a? String
    CustomField.parse_phone_string_to_hash(data)
  end

   def fetch_dialing_code(country_by_alpha3)
    return unless country_by_alpha3.present?
    ISO3166::Country.find_country_by_alpha3(country_by_alpha3)&.country_code
  end

   def fetch_national_prefix(country_by_alpha3)
    return unless country_by_alpha3.present?
    ISO3166::Country.find_country_by_alpha3(country_by_alpha3)&.national_prefix
  end

   def fetch_country(country)
    return unless country.present?
    Country.where('name ILIKE ? OR key ILIKE ?', country, country).take
  end

   def fetch_state(country, state)
    return unless country.present? && state.present?
    fetch_country(country)&.states&.where('name ILIKE ? OR key ILIKE ?', state, state)&.take
  end

  def fetch_template_value(adp_wfn_api = nil, adp_onboarding_template, enviornment, version)
    adp_wfn_onboarding_templates = adp_wfn_api.integration_credentials.find_by(name: "Onboarding Templates")&.dropdown_options
    unless adp_wfn_onboarding_templates.present? && adp_onboarding_template.present?
      create_loggings(adp_wfn_api.company, "ADP Workforce Now - #{enviornment}", 401, 'Empty Onboarding Templates', {user_adp_template: adp_onboarding_template, dropdown_options: adp_wfn_onboarding_templates, company_id: adp_wfn_api.company_id})
      return nil
    end

    ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_wfn_api).sync

    onboarding_templates = adp_wfn_api&.reload&.integration_credentials.find_by(name: "Onboarding Templates")&.dropdown_options

    if version == 'v2' # || adp_wfn_api.enable_international_templates.present?
      code_value = onboarding_templates[enviornment.downcase].select { |onboarding_template| onboarding_template['template_name'] == adp_onboarding_template || 
        onboarding_template['codeValue'] == adp_onboarding_template }[0]['codeValue'] rescue nil
      return (code_value || adp_onboarding_template)
    else
      onboarding_templates = filter_out_international_templates(onboarding_templates[enviornment.downcase], enviornment)
      return onboarding_templates.select { |onboarding_template| onboarding_template['template_name'] == adp_onboarding_template || 
        onboarding_template['codeValue'] == adp_onboarding_template }[0]['template_name'] rescue adp_onboarding_template
    end
  end
  
  def fetch_adp_manager_position_id(company, manager, enviornment, access_token, certificate)
    adp_manager_id = fetch_adp_wfn_id(enviornment, manager)
    return unless adp_manager_id.present?

    manager_id = nil

    begin
      response = events_service.fetch_worker(access_token, certificate, adp_manager_id)
      if response&.status != 200
        if response.status != 204
          create_loggings(company, "ADP Workforce Now - #{enviornment}", 500, "Fetch manager position id (#{manager.id}) From ADP - Failure", {result: response.status}, {request: "GET WORKER/#{manager.id}"})
        end
      end

      response = JSON.parse(response.body)
      
      position_id = fetch_work_assignment(response)
      manager_id = position_id['positionID'] if position_id.present? 
      if manager_id.present?
        create_loggings(company, "ADP Workforce Now - #{enviornment}", 200, "Fetch manager position id (#{manager.id}) From ADP - Success", {result: response.inspect}, {request: "GET WORKER/#{manager.id}"})
      else
        create_loggings(company, "ADP Workforce Now - #{enviornment}", 500, "Fetch manager position id (#{manager.id}) From ADP - Failure", {result: response.inspect}, {request: "GET WORKER/#{manager.id}"})
      end

    rescue Exception => e
      create_loggings(company, "ADP Workforce Now - #{enviornment}", 500, "Fetch manager position id (#{manager.id}) From ADP - Failure", {result: e.message}, {request: "GET WORKER/#{manager.id}"})
    end 

    return manager_id
  end

  def fetch_work_assignment(response)
    work_assignments = response['workers'][0]['workAssignments'] rescue nil
    return unless work_assignments.present?

    # active_work_assignment = work_assignments.select { |worker_assignment| ['A', 'T'].include?(worker_assignment['assignmentStatus']['statusCode']['codeValue']) && worker_assignment['primaryIndicator'] == true }.last rescue {}
    active_work_assignment = work_assignments.select { |worker_assignment| worker_assignment['primaryIndicator'] == true }.last rescue {}
    # if active_work_assignment.blank?
    #   active_work_assignment = work_assignments.last rescue {}
    # end
    active_work_assignment
  end

  def fetch_company_code_based_code_value(list_name, user, company_code, access_token, certificate)
    case list_name
    when 'team'
      fetch_code(user.company.department_mapping_key.downcase.pluralize, user.team&.name, company_code, access_token, certificate)
    when 'location'
      fetch_code(user.company.location_mapping_key.downcase.pluralize, user.location&.name, company_code, access_token, certificate)
    end
  end

  def get_preference_field_data(key, user, enviornment)
    case key
    when 'first_name', 'last_name', 'preferred_name', 'personal_email', 'start_date'
      user[key].to_s
    when 'job_title'
      fetch_enviornment_based_code_value(user.title, user.company_id, enviornment, 'JobTitle')
    when 'company_email'
      user.email
    end
  end

  def get_default_fields_array()
    [ {default_field_id: 'fn', params_key: 'first_name'}, {default_field_id: 'ln', params_key: 'last_name'}, {default_field_id: 'st', params_key: 'start_date'},
      {default_field_id: 'jt', params_key: 'job_title'}, {default_field_id: 'pn', params_key: 'preferred_name'}, {default_field_id: 'pe', params_key: 'personal_email'},
      {default_field_id: 'ce', params_key: 'company_email'} ]
  end

  def fetch_enviornment_based_code_value(value, company_id, enviornment, object_name, is_dpt_or_loc = false)
    object = is_dpt_or_loc ? value : object_name.constantize.where('name ILIKE ? AND company_id = ?', value, company_id).take
    enviornment == 'US' ? object&.adp_wfn_us_code_value.to_s : object&.adp_wfn_can_code_value.to_s
  end

  def fetch_department_code_value(team, company_id, company_code, enviornment)
    return unless team
    value = enviornment == 'US' ? JSON.parse(team.adp_wfn_us_code_value) : JSON.parse(team.adp_wfn_can_code_value) rescue team.send("adp_wfn_#{enviornment.downcase}_code_value")
    return unless value
    value.is_a?(String) || value.is_a?(Integer) ? value.to_s : (value[company_code] || value['default'])
  end

  def fetch_adp_correlation_id_from_response(response); response['Adp-correlationid'] unless Rails.env.test? rescue nil end
  def user_has_company_code?(user); user.custom_field_values.joins(:custom_field).where(custom_fields: {name: 'ADP Company Code'}).take&.custom_field_option_id.present? end
  def has_international_template?(user); user.adp_onboarding_template ? user.adp_onboarding_template.include?('- International') : nil end

  def build_race_ethnicity_data(data, user, enviornment, version)
    # if not hispanic or latino, we need to pass '4' in the ethnicity, which indicates non-hispanic or latino.
    data[:race_id_method] = validate_race_id_method(user.get_custom_field_value_adp_code('Race ID Method', enviornment))
    ethnicity = user.get_custom_field_value_text_by_profile_template_check('Race/Ethnicity')
    if (version == 'v2') && ['hispanic or latino'].exclude?(ethnicity&.downcase)
      data[:ethnicity] = '4'
      data[:race] = validate_race_ethnicity(user.get_custom_field_value_adp_code('Race/Ethnicity', enviornment))
    else
      data[:ethnicity] = validate_race_ethnicity(user.get_custom_field_value_adp_code('Race/Ethnicity', enviornment))
    end
    data[:race_id_method] ||= 'SID' if data[:race] || (data[:ethnicity] != '4') 
    data
  end


  def build_update_race_params(user, enviornment)
    race_id_method, race_code_value = ['Race ID Method', 'Race/Ethnicity'].map { |att| user.get_custom_field_value_adp_code(att, enviornment)}
    race_id_method_value = race_id_method || (race_code_value ? 'SID' : nil)
    return race_id_method_value, race_code_value
  end

  def update_params(response, params) 
    if response.status == 400
      response = JSON.parse(response&.body)
      error_message = response.dig('_confirmMessage', 'messages', 0, 'messageText')
      dig_path = NULLIFY_METHODS_HASH[:"#{error_message}"]
      send("nullify_field_data", params, dig_path) if dig_path.present?
    end
  end
  
  private

  def nullify_field_data(data, dig_path)
    data.dig(*dig_path)&.transform_values! { |value| nil }
  end

  def fetch_code(list_name, value, company_code, access_token, certificate)
    begin
      response = events_service.fetch_code_lists(list_name, access_token, certificate)
      
      if response&.status == 200
        result = JSON.parse(response.body)
        list_items = result['codeLists'][0]['listItems'] rescue []

        return list_items.select { |list_item| (list_items['shortName'] || list_items['longName']).downcase == value.downcase && 
          list_name['foreignKey'].downcase == company_code.downcase }[0]['codeValue'] rescue nil
      end
    rescue Exception => e
    end
  end

  def apply_to_location?(meta, user)
    location_ids = meta['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(meta, user)
    team_ids = meta['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(meta, user)
    employee_types = meta['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end

  def filter_out_international_templates(onboarding_templates, enviornment)
    supported_onboarding_templates = ['HR + Payroll (System)', 'HR + Payroll + Time (System)', 'HR + Time (System)', 'HR Only (System)', 'Applicant Onboard', 'Applicant Onboard US']
    selected_onboarding_templates = [] 

    onboarding_templates.clone.each do |onboarding_template|
      onboarding_template.clone.each do |k, v|
        name = v.split('-')
        if supported_onboarding_templates.include?(name[0].strip) && 
           ((enviornment == 'US' && (name[name.length-1].strip.downcase == 'us')) || (enviornment == 'CAN' && (name[name.length-1].strip.downcase == 'canada') || Rails.env == 'staging'))
          onboarding_template['template_name'] = onboarding_template.delete(k)
          selected_onboarding_templates.push(onboarding_template)
        end
      end
    end
    selected_onboarding_templates     
  end

  def fetch_adp_wfn_id(enviornment, user)
    enviornment == 'US' ? user.adp_wfn_us_id : user.adp_wfn_can_id
  end

  def fetch_adp_country_code_by_name(country_name)
    HrisIntegrationsService::AdpWorkforceNowU::StaticAdpCountryCodesList.static_company_codes[country_name]
  end

  def events_service
    HrisIntegrationsService::AdpWorkforceNowU::Events.new
  end
end
