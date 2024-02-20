class HrisIntegrationsService::Bamboo::DigitalOcean::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData
  attr_reader :company

  def initialize(company)
    super(company)
    custom_fields["customEthnicity/Race"] = custom_fields.delete(:ethnicity)
  end

  def manage_custom_fields(user)
    super(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields['customEthnicity/Race'], bamboo_data['race/ethnicity'])
  end
end