class HrisIntegrationsService::Trinet::DataBuilder
  attr_reader :parameter_mappings

  delegate :fetch_options, to: :endpoint_service, prefix: :execute
  delegate :fetch_integration, to: :helper_service

  delegate :get_numeric_salary, to: :integrations_helper_service

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    @parameter_mappings.each do | key, value|
      if value[:exclude_in_create].blank?
        data[key] = fetch_data(value, user)
      end
    end
    data
  end

  def build_update_profile_data(user, updated_attributes)
    data = {}
    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && updated_attributes.include?(value[:name])
        data[key] = fetch_data(value, user)
      end
    end
    data
  end

  private

  def format_date(value)
    return unless value.present?
    value.to_date.strftime('%Y-%m-%d')  
  end

  def get_contact_information(user)
    home_address = user.get_custom_field_value_text("Home Address", true)
    mobile_contact = user.get_custom_field_value_text("mobile phone number", true)
    
    data = {}
    
    if home_address.present?
      data[:address1] = home_address[:line1]
      data[:address2] = home_address[:line2]
      data[:city] = home_address[:city]
      data[:postalCode] = home_address[:zip]
      data[:state] = map_state_value(home_address[:state])
      data[:country] = map_country_value(home_address[:country])
    end
    
    data[:phone] =  mobile_contact
    data
  end

  def fetch_data(meta, user)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase
    
    case field_name
    when 'gender', 'employment status', 'new hire', 'regular/temporary', 'flsa status', 'race/ethnicity'
      return fetch_mapped_value(user, field_name)&.upcase
    when 'location id'
      return fetch_trinet_option_id('locations', user) if user.location.present?
    when 'manager id'
      return fetch_trinet_option_id('employees?offset=1', user) if user.manager.present?
    when 'team id'
      return fetch_trinet_option_id('departments', user) if user.team.present?
     when 'job code'
      return fetch_trinet_option_id('jobs', user, field_name)
     when 'workers comp code'
      return fetch_trinet_option_id('workers-comp-codes', user, field_name)
     when 'pay groups'
      return fetch_trinet_option_id('paygroups', user, field_name)
    when 'benefits group', 'future benefits group'
      return fetch_trinet_option_id('benefit-classes', user, field_name)
    when 'date of birth'
      return format_date(user.get_custom_field_value_text(field_name))
    when 'start date'
      return format_date(user.attributes[field_name.tr(' ', '_')]) 
    when 'effective date'
      return format_date(Date.today) 
    when 'home contact'
      return get_contact_information(user)
    when 'name type'
      return 'PRF'
    when 'country'
      return user.get_custom_field_value_text("home address", false, 'Country') == 'Canada' ? 'CA' : 'US'
    when 'annual salary'
      return get_numeric_salary(user)
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else
         user.get_custom_field_value_text(field_name)
      end
    end
  end

  def map_new_hire(value)
    if value == 'hire on paid leave'
      return 'plv'
    elsif value == 'hire on unpaid leave'
      return 'ulv'
    elsif value == 'new hire'
      return 'hir'
    elsif value == 'rehire'
      return 'reh'
    end
  end

  def map_gender_value(value)
    return value[0] if ['female', 'male'].include?(value)   
  end

  def map_employement_Status_value(value)
    return value[0] if ['part time', 'full time'].include?(value)   
  end

  def map_regular_temporary(value)
    return value[0] if ['regular', 'temporary'].include?(value)   
  end

  def map_flsa_status(value)
    case value
    when 'computer professional-exempt'
      'c'
    when 'computer professional-non-exempt'
      'z'
    when'exempt'
      't'
    when 'non-exempt'
      'n'
    end
  end

  def map_ethnicity(value)
    case value
    when 'hispanic/latino'
      'hispa'
    when 'white (not hispanic or latino)'
      'white'
    when 'black/african american (not hispanic or latino)'
      'black'
    when 'native hawaiian/other pac island (not hispanic or latino)'
      'pacif'
    when 'asian (not hispanic or latino)'
      'asian'
    when 'american indian/alaska native (not hispanic or latino)'
      'amind'
    when 'two or more races (not hispanic or latino)'
      'two'
    when 'decline to specify'
      'nspec'
    end
  end

  def fetch_mapped_value(user, field_name)  
    value = user.get_custom_field_value_text(field_name).try(:downcase)
    return unless value.present?

    case field_name
    when 'gender'
      map_gender_value(value)
    when 'employment status'
      map_employement_Status_value(value)
    when 'new hire'
      map_new_hire(value)
    when 'regular/temporary'
      map_regular_temporary(value)
    when 'flsa status'
      map_flsa_status(value)
    when 'race/ethnicity'
      map_ethnicity(value)
    end
  end

  def map_country_value(country_name)
    country = ISO3166::Country.find_country_by_any_name("United States")
     return country.present? ? country.alpha2 : "US"
  end

  def map_state_value(state_name)
    State.find_by_name(state_name).try(:key) || state_name
  end

  def fetch_trinet_options(endpoint, user)
    response = execute_fetch_options(fetch_integration(user.company, user), endpoint) rescue {}
    JSON.parse(response.body)['data'] rescue []
  end

  def fetch_trinet_option_id(endpoint, user, field_name=nil)
    options = fetch_trinet_options(endpoint, user)

    if endpoint == 'locations'
      return options.select { |parsed_location| parsed_location['locationName'].downcase == user.location&.name&.downcase }[0]['locationId'] rescue nil
    elsif endpoint == 'employees?offset=1'
      offset = 1
      while options.present?
        id = options['employeeData'].select { |employee| employee['employmentInfo']['workEmail'] == user.manager.email}[0]['employeeId'] rescue nil

        if id.blank? && options['hasMore']
          offset += 100
          endpoint = "employees?offset=#{offset}"
          options = fetch_trinet_options(endpoint, user)
        else
          break
        end
      end

      return id
    elsif endpoint == 'departments'
      return options.select { |department| department['deptName'].downcase == user.team&.name&.downcase }[0]['deptId'] rescue nil
    elsif endpoint == 'jobs'
      value = user.get_custom_field_value_text(field_name)
      return value.present? ? options.select { |job| job['value'].downcase == value.downcase }[0]['key'] : '' rescue nil
    elsif endpoint =='workers-comp-codes'
      value = user.get_custom_field_value_text(field_name)
      return value.present? ? options.select { |code| code['description'].downcase == value.downcase }[0]['code'] : '' rescue nil 
    elsif endpoint =='paygroups'
      value = user.get_custom_field_value_text(field_name)
      return value.present? ? options.select { |paygroup| paygroup['payGroupDescription'].downcase == value.downcase }[0]['payGroupId'] : '' rescue nil 
    elsif endpoint =='benefit-classes'
      value = user.get_custom_field_value_text(field_name)
      return value.present? ? options.select { |benefit| benefit['benefitClassName'].downcase == value.downcase }[0]['benefitClassCode'] : '' rescue nil 
 
    end
  end
  
  def endpoint_service
    HrisIntegrationsService::Trinet::Endpoint.new
  end

  def helper_service
    HrisIntegrationsService::Trinet::Helper.new
  end

  def integrations_helper_service
    IntegrationCustomMappingHelper.new
  end
end