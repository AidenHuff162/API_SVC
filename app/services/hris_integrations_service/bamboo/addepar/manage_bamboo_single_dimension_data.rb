class HrisIntegrationsService::Bamboo::Addepar::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    custom_fields.merge! ({
      't-shirt size' => :customShirtsize,
      'dietary preferences or restrictions' => :customDietaryPreferencesorRestrictions,
      'Payroll Group' => :payGroup
    })
  end

  def prepare_custom_data
    data = super

    data[custom_fields['t-shirt size']] = user.get_custom_field_value_text(custom_fields.key(:customShirtsize))
    data[custom_fields['dietary preferences or restrictions']] = user.get_custom_field_value_text(custom_fields.key(:customDietaryPreferencesorRestrictions))
    data[custom_fields['Payroll Group']] = user.get_custom_field_value_text(custom_fields.key(:payGroup))
    data.except!(nil)
  end

  def get_single_dimension_data(field_name)
    data = super(field_name)
    data.except!(nil)
  end
end
