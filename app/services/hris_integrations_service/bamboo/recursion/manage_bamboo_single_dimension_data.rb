class HrisIntegrationsService::Bamboo::Recursion::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    custom_fields.merge! ({
      'gender' => :customGender,
      'employee #' => :employeeNumber
    })
  end

  def prepare_custom_data
    data = super
    data[custom_fields['gender']] = user.get_custom_field_value_text(custom_fields.key(:customGender))
    data[custom_fields['employee #']] = user.get_custom_field_value_text(custom_fields.key(:employeeNumber))
    data.compact!
  end
end

