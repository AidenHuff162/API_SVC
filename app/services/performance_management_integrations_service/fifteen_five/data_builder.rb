class PerformanceManagementIntegrationsService::FifteenFive::DataBuilder
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
    field_name = meta[:name].to_s.downcase

    case field_name
    when 'manager'
      user.manager&.fifteen_five_id
    when 'state'
      user.active?
    when 'user name'
      user.full_name.downcase.tr(' ', '_') + ".#{user.id}"
    when 'location'
      user.location&.name&.strip
    when 'department'
      # fetch_group_id('department', user.team&.name&.downcase) if user.team.present?
    when 'start date'
      user.start_date&.strftime('%m/%d/%Y')
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      end
    end
  end
end