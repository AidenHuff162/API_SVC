class LearningAndDevelopmentIntegrationServices::Kallidus::DataBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(user)
    data = {}

    @parameter_mappings.each do |key, value|
      if value[:exclude_in_create].blank?
        data_value = fetch_data(value, user)
        data[key] = data_value unless data_value.nil?
      end
    end

    data
  end

  def build_update_profile_data(user, updated_attributes)
    data = {}
    
    if updated_attributes.present?
      updated_attributes.push('id')
      updated_attributes.push('email') if updated_attributes.exclude?('email') 
      updated_attributes.push('last day worked') if user.last_day_worked.present? && updated_attributes.exclude?('last day worked')
    end

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
    value.to_datetime.to_s  
  end

  def fetch_data(meta, user)
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase

    case field_name
    when 'start date'
      format_date(user.start_date)
    when 'last day worked'
      format_date(user.last_day_worked)
    when 'email'
      user.email || user.personal_email
    when 'company email'
      user.email
    when 'status'
      user.active?
    when 'manager'
      user&.manager&.id
    when 'location'
      user&.location&.name.to_s
    when 'department'
      user&.team&.name.to_s
    when 'job title'
      user.title
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')].to_s
      else
        user.get_custom_field_value_text(field_name).to_s
      end
    end
  end
end
