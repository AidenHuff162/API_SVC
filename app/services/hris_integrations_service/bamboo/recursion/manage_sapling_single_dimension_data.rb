class HrisIntegrationsService::Bamboo::Recursion::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData

  def initialize(company)
    super(company)
    custom_fields.merge! ({
      customGender: 'gender',
      employeeNumber: 'employee #' 
    })
  end

  def manage_custom_fields(user)
    super(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customGender], bamboo_data['customGender'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:employeeNumber], bamboo_data['employeeNumber'])
  end
end
