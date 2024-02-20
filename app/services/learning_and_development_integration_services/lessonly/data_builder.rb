class LearningAndDevelopmentIntegrationServices::Lessonly::DataBuilder
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

  def build_update_profile_data(user, updated_attributes)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_update].blank? && (updated_attributes.include?('all') || updated_attributes.include?(value[:name]))
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

  def fetch_data(meta, user)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase

    case field_name
    when 'start date'
      format_date(user.start_date)
    when 'username'
      user.preferred_full_name
    when 'team id'
      user.team&.name
    when 'location id'
      user.location&.name
    when 'manager id'
      user.manager&.preferred_full_name
    when 'role'
      if user.account_owner?
        return 'admin'
      elsif user.managed_users.present?
        return 'manager'
      else
        return 'learner'
      end
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else
        user.get_custom_field_value_text(field_name)
      end
    end
  end
end