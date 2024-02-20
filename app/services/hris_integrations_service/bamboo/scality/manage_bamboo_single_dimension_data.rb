class HrisIntegrationsService::Bamboo::Scality::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    custom_fields.merge! ({
      'allergies' => :customAllergies,
      't-shirt size' => :customShirtsize
    })
  end

  def prepare_custom_data
    data = super
    data[custom_fields['allergies']] = user.get_custom_field_value_text(custom_fields.key(:customAllergies))
    data[custom_fields['t-shirt size']] = user.get_custom_field_value_text(custom_fields.key(:customShirtsize))
    data.except!(nil)
  end
end

