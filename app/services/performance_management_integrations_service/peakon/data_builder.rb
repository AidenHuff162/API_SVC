class PerformanceManagementIntegrationsService::Peakon::DataBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank?
        data_value = fetch_data(value, user)
        data[key] = data_value if data_value.present?
      end
    end

    data
  end

  def build_update_profile_data(user, updated_attributes, request_type = 'scim')
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
    when 'manager id'
      user.manager&.peakon_id
    when 'state'
      user.active?
    when 'location id'
      user.location&.name&.strip
    when 'team id'
      user.team.try(:name)
    when 'date of birth'
      return format_date(user.get_custom_field_value_text(field_name))
    when 'start date'
      return format_date(user.attributes[field_name.tr(' ', '_')]) 
    when 'termination_date'
      return format_date(user.attributes[field_name.tr(' ', '_')]) 
    when 'employment status'
      user.employee_type_field_option&.option
    when 'full name'
      user.full_name
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else
         user.get_custom_field_value_text(field_name)
      end
    end
  end
end