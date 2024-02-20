class HrisIntegrationsService::Gusto::DataBuilder

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

  def map_flsa_status(value)
    return unless value.present?

    case value
    when 'salary/no overtime'
      'Exempt'
    when 'salary/eligible for overtime'
      'Salaried Nonexempt'
    when 'paid by the hour'
      'Nonexempt'
    end
  end

  def fetch_data(meta, user)
    
    return unless user.present? && meta.present?
    field_name = meta[:name].to_s.downcase
    case field_name
    when 'start date', 'last day worked'
      format_date(user.attributes[field_name.tr(' ', '_')])
    when 'date of birth'
      format_date(user.get_custom_field_value_text(field_name))
    when 'home address'
      user.get_custom_field_value_text(field_name, true)
    when 'pay rate'
      user.get_custom_field_value_text(field_name, false, 'Currency Value')
    when 'flsa status'
      map_flsa_status(user.get_custom_field_value_text(field_name).try(:downcase))
    else
      if meta[:is_custom].blank?
        user.attributes[field_name.tr(' ', '_')]
      else  
        user.get_custom_field_value_text(field_name)
      end
    end
  end
end