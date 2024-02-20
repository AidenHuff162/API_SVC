class SsoIntegrationsService::ActiveDirectory::DataBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank?
        fetched_data = fetch_data(value, user)
        
        if fetched_data.present?
          data[key] = fetched_data
        end
      end
    end

    data
  end

  def build_update_profile_data(user, updated_attributes)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && updated_attributes.include?(value[:name])
        fetched_data = fetch_data(value, user)
        data[key] = fetched_data.present? ? fetched_data : nil
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
      # user.manager&.fifteen_five_id
    when 'state'
      user.active?.to_s
    when 'display name'
      user.preferred_full_name
    when 'location'
      user.location&.name&.strip
    when 'team'
      user.team&.name&.strip
    when 'start date'
      user.start_date&.to_datetime&.to_s
    when 'user type'
      'Member'
    when 'mail nick name'
      user.preferred_full_name.downcase.tr(' ', '_') + ".#{user.id}"
    else
      if meta[:is_custom].blank?
        return user.attributes[field_name.tr(' ', '_')]
      else
        return user.get_custom_field_value_text(field_name)
      end
    end
  end
end