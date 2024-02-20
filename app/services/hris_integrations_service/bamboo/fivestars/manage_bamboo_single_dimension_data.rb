class HrisIntegrationsService::Bamboo::Fivestars::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    custom_fields.merge!({
      't-shirt size' => 'customT-ShirtSize',
      'flsa code' => :exempt,
      'spirit animal' => :customSpiritAnimal,
      'food allergies / dietary restrictions' => :customDietaryRestrictions,
      'benefits eligible' => :customSyncToSequoia,
      'standard hours per week' => :standardHoursPerWeek,
      'favorite food' => :customFavoriteFood,
      'one interesting fact' => :customOneInterestingFact
    })
  end

  def prepare_custom_data
    data = super

    data[custom_fields['t-shirt size']] = user.get_custom_field_value_text(custom_fields.key('customT-ShirtSize'))
    data[custom_fields['flsa code']] = user.get_custom_field_value_text(custom_fields.key(:exempt))
    data[custom_fields['spirit animal']] = user.get_custom_field_value_text(custom_fields.key(:customSpiritAnimal))
    data[custom_fields['food allergies / dietary restrictions']] = user.get_custom_field_value_text(custom_fields.key(:customDietaryRestrictions))
    data[custom_fields['benefits eligible']] = map_confirmation_field(user.get_custom_field_value_text(custom_fields.key(:customSyncToSequoia)))
    data[custom_fields['standard hours per week']] = user.get_custom_field_value_text(custom_fields.key(:standardHoursPerWeek))
    data[custom_fields['favorite food']] = user.get_custom_field_value_text(custom_fields.key(:customFavoriteFood))
    data[custom_fields['one interesting fact']] = user.get_custom_field_value_text(custom_fields.key(:customOneInterestingFact))
    data.except!(nil)
  end

  def get_single_dimension_data(field_name)
    if field_name.try(:downcase) == 'benefits eligible'
      data = {}
      data[custom_fields[field_name.try(:downcase)]] = map_confirmation_field(user.get_custom_field_value_text(field_name.try(:downcase)))
    else
      data = super(field_name)
    end
    data.except!(nil)
  end

  private
  def map_confirmation_field(option)
    if option.present?
      if option == 'true'
        return '1'
      else
        return '0'
      end
    end
  end
end
