class HrisIntegrationsService::Workday::FieldOptionMapper
  attr_reader :company

  def initialize(company)
    @company = company
  end

  # Sapling Mappers
  def map_to_sapling_country(country_code)
    Country.find_by(key: country_code).try(:name) rescue nil
  end

  def map_to_sapling_state(country_code, state_code)
    Country.find_by(key: country_code).states.find_by(key: state_code).try(:name) rescue nil
  end

  def map_to_sapling_phone_format(phone_number)
    CustomField.parse_phone_string_to_hash(phone_number)
  end

  def map_to_sapling_ld(company, type, data)
    ld_hash = { location: 'locations', department: 'teams' }
    company.send(ld_hash[type]).where('name ILIKE ?', data).first_or_create(name: data).id rescue nil
  end

  def map_to_sapling_manager(company, workday_manager_id)
    return if workday_manager_id.blank?

    company.users.find_by(workday_id: workday_manager_id).try(:id)
  end

  def map_to_sapling_custom_field_option(field_name, workday_reference)
    custom_field = company.custom_fields.find_by('name ILIKE ?', field_name)
    return if custom_field.blank? || workday_reference.blank?

    workday_wid, workday_option = workday_reference
    option = custom_field.custom_field_options.find_by(workday_wid: workday_wid).try(:option)
    if option.blank? && workday_option.present?
      custom_field_option = custom_field.custom_field_options.where('option ILIKE ?', workday_option).first_or_create(option: workday_option)
      custom_field_option.update(workday_wid: workday_wid) if workday_wid.present?
    end

    custom_field.custom_field_options.find_by(workday_wid: workday_wid).try(:option)
  end

  def get_state_value(states, state)
    return state if states.blank?

    states.find_by(name: state).try(:key) || states.find_by(key: state).try(:key)
  end

  def map_to_workday_address(value)
    return {} unless value.except(:line2).values.all?(&:present?) # absence of line2 doesn't matter

    country = Country.find_by(name: value[:country])
    value[:country] = country.try(:key)
    value[:state] = get_state_value(country&.states, value[:state])
    value
  end

  def map_to_workday_phone(value)
    return {} unless value.values.all?(&:present?) # country, area_code, number all should be present

    value[:country] = "#{value[:country]}_#{ISO3166::Country.find_country_by_alpha3(value[:country]).country_code}"
    value
  end
end
