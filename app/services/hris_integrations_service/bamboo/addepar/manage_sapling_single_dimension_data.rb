class HrisIntegrationsService::Bamboo::Addepar::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData

  def initialize(company)
    super(company)
    custom_fields.merge! ({
      customShirtsize: 'T-Shirt Size'
    })
  end

  def manage_custom_fields(user)
    super(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customShirtsize], bamboo_data['customShirtsize'])
  end
end
