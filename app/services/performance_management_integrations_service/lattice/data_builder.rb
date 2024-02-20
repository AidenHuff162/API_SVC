class PerformanceManagementIntegrationsService::Lattice::DataBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank?
        data[key] = fetch_data(value, user)
      end
    end

    data
  end

  def build_update_profile_data(user, updated_attributes, request_type = 'scim')
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && request_type == 'scim'
        data[key] = fetch_data(value, user)
      elsif request_type == 'api'
        data[key] = fetch_data(value, user)
      end
    end

    data
  end

  private

  def fetch_data(meta, user)
    return unless user.present? && meta.present?
    field_name = meta[:name]
    case field_name
    when 'id'
      user.id.to_s
    when 'manager'
      user.manager&.lattice_id
    when 'state'
      user.active?
    when 'start date'
      user.start_date&.strftime('%m/%d/%Y')
    when 'department'
      user.team&.name
    when 'mobile phone number'
      user.get_custom_field_value_text(field_name, false, nil, nil, false, nil, false, false, false, false, nil, false, true)
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else
        user.get_custom_field_value_text(field_name)
      end
    end
  end
end