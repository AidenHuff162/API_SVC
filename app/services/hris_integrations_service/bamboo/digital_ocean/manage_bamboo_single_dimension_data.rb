class HrisIntegrationsService::Bamboo::DigitalOcean::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    @custom_fields['race/ethnicity'] = 'customEthnicity/Race'
  end

  def prepare_custom_data
    data = super

    data[custom_fields['race/ethnicity']] = user.get_custom_field_value_text(custom_fields.key('customEthnicity/Race'))
    data.except!(nil)
    data.each_with_object({}) { |(key, value), hash| hash[key] = value.present? ? value.gsub('&', '&amp;') : value }
  end

  def get_single_dimension_data(field_name)
    data = super(field_name)
    
    data.except!(nil)
    data.each_with_object({}) { |(key, value), hash| hash[key] = value.present? ? value.gsub('&', '&amp;') : value }
  end
end
