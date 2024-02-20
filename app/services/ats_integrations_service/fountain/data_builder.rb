class AtsIntegrationsService::Fountain::DataBuilder
  attr_reader :parameter_mappings

  def initialize(parameter_mappings)
    @parameter_mappings = parameter_mappings
  end

  def build_create_profile_data(params)
    data = { custom_fields: {} }
    @parameter_mappings.each do |key, value|
      get_data(key, value, data, params)
    end
    data
  end

  def get_data(key, value, data, params)
    if value[:is_custom].blank?
      data[key] = fetch_value(value, params)
    else
      data[:custom_fields].merge!("#{key}": fetch_value(value, params))
    end
  end

  def fetch_value(value, params)
    if value[:is_split].present?
      params["#{value[:name]}"].split(" ", 2)[value[:split_index]]
    else
      params["#{value[:name]}"]
    end
  end
end
