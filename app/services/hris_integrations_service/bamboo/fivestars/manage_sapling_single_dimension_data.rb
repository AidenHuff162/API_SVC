class HrisIntegrationsService::Bamboo::Fivestars::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData

  def initialize(company)
    super(company)
    custom_fields.merge! ({
      'customT-ShirtSize' => 'T-Shirt Size',
      exempt: 'FLSA Code',
      customSpiritAnimal: 'Spirit Animal',
      customDietaryRestrictions: 'Food Allergies / Dietary Restrictions',
      customSyncToSequoia: 'Benefits Eligible',
      standardHoursPerWeek: 'Standard Hours Per Week',
      customOneInterestingFact: 'One Interesting Fact'
    })
  end

  def manage_custom_fields(user)
    super(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields['customT-ShirtSize'], bamboo_data['customT-ShirtSize'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:exempt], bamboo_data['exempt'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customSpiritAnimal], bamboo_data['customSpiritAnimal'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customDietaryRestrictions], bamboo_data['customDietaryRestrictions'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customSyncToSequoia], map_confirmation_field(bamboo_data['customSyncToSequoia']))
    CustomFieldValue.set_custom_field_value(user, custom_fields[:standardHoursPerWeek], bamboo_data['standardHoursPerWeek'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customOneInterestingFact], bamboo_data['customOneInterestingFact'])
  end

  private
  def map_confirmation_field(option)
    if option.present?
      if option == '1'
        return "true"
      else
        return "false"
      end
    end
  end
end
