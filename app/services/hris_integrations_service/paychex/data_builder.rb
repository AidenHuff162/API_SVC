class HrisIntegrationsService::Paychex::DataBuilder
  attr_reader :parameter_mappings

  delegate :fetch_options, to: :endpoint_service, prefix: :execute
  delegate :fetch_integration, to: :helper_service

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
    value.to_date.strftime('%Y-%m-%dT%H:%M:%SZ')  
  end
  
  def fetch_data(meta, user)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase
    
    case field_name
    when 'worker type'
      'EMPLOYEE'
    when 'exemption type', 'race/ethnicity', 'gender', 'employment status'
      return fetch_mapped_value(user, field_name)&.upcase&.tr(' ', '_')
    when 'location id'
      return fetch_paychex_option_id('locations', user) if user.location.present?
    when 'title'
      return fetch_paychex_option_id('jobtitles', user) if user.title.present?
    when 'manager id'
      user.manager&.paychex_id
    when 'tax'
      value = user.get_custom_field_value_text(field_name, true)
      if value.present? && value[:tax_value].present?
        return { legalIdType: value[:tax_type], legalIdValue: value[:tax_value] }
      end
    when 'date of birth'
      return format_date(user.get_custom_field_value_text(field_name))
    when 'start date'
      return format_date(user.attributes[field_name.tr(' ', '_')]) 
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else
         user.get_custom_field_value_text(field_name)
      end
    end
  end

  def map_exemption_value(value)
    return value if ['exempt', 'non exempt'].include?(value)
  end

  def map_exthnicity_value(value)
    return value if ['hispanic or latino', 'white not of hispanic origin', 'black or african american', 'native hawaiian or other pacific island', 
      'american indian or alaskan native', 'two or more races', 'asian or pacific islander' ].include?(value)
  end

  def map_gender_value(value)
    return value if ['female', 'male', 'unknown', 'not specified'].include?(value)   
  end

  def map_employement_Status_value(value)
    return value if ['part time', 'full time'].include?(value)   
  end

  def fetch_mapped_value(user, field_name)  
    value = user.get_custom_field_value_text(field_name).try(:downcase)
    return unless value.present?

    case field_name
    when 'exemption type'
      map_exemption_value(value)
    when 'race/ethnicity'
      map_exthnicity_value(value)
    when 'gender'
      map_gender_value(value)
    when 'employment status'
      map_employement_Status_value(value)
    end
  end

  def fetch_paychex_options(endpoint, company)
    response = execute_fetch_options(fetch_integration(company), endpoint) rescue {}
    JSON.parse(response.body)['content'] rescue []
  end

  def fetch_paychex_option_id(endpoint, user)
    options = fetch_paychex_options(endpoint, user.company)

    if endpoint == 'locations'
      return options.select { |option| option['name'].downcase == user.location.name.downcase }[0]['locationId'] rescue nil
    elsif endpoint == 'jobtitles'
      return options.select { |option| option['title'].downcase == user.title.downcase }[0]['jobTitleId'] rescue nil
    end
  end

  def endpoint_service
    HrisIntegrationsService::Paychex::Endpoint.new
  end

  def helper_service
    HrisIntegrationsService::Paychex::Helper.new
  end
end