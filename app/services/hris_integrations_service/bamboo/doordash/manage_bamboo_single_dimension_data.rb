class HrisIntegrationsService::Bamboo::Doordash::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    @custom_fields.merge! ({
      'adp file number' => :customADPFileNumber,
      'eeoc' => :customETHNICITY,
      'marital status' => :maritalStatus,
      'eeo job category' => :eeo,
      'sin' => :sin,
      'division' => :division,
      'group' => :customGroup,
      'team' => :customTeam,
      'gender identity' => :customGenderIdentity,
      'pronouns' => :customPronouns,
      'doordash entity' => :customDoorDashEntity,
      'business line' => :customCostCenter,
      't-shirt size' => :customShirtSize,
      'where will this new hire attend orientation?' => :customOrientation 
    })
  end

  def prepare_custom_data
    data = super

    data[custom_fields['adp file number']] = user.get_custom_field_value_text(custom_fields.key(:customADPFileNumber))
    data[custom_fields['eeoc']] = user.get_custom_field_value_text(custom_fields.key(:customETHNICITY))
    data[custom_fields['marital status']] = user.get_custom_field_value_text('marital status')
    data[custom_fields['eeo job category']] = user.get_custom_field_value_text(custom_fields.key(:eeo))
    data[custom_fields['sin']] = user.get_custom_field_value_text(custom_fields.key(:sin))
    data[custom_fields['division']] = user.get_custom_field_value_text(custom_fields.key(:division))
    data[custom_fields['group']] = user.get_custom_field_value_text(custom_fields.key(:customGroup))

    data[custom_fields['team']] = user.get_custom_field_value_text(custom_fields.key(:customTeam))
    data[custom_fields['gender identity']] = user.get_custom_field_value_text(custom_fields.key(:customGenderIdentity))
    data[custom_fields['pronouns']] = user.get_custom_field_value_text(custom_fields.key(:customPronouns))
    data[custom_fields['doordash entity']] = user.get_custom_field_value_text(custom_fields.key(:customDoorDashEntity))
    data[custom_fields['business line']] = user.get_custom_field_value_text(custom_fields.key(:customCostCenter))
    data[custom_fields['t-shirt size']] = user.get_custom_field_value_text(custom_fields.key(:customShirtSize))
    data[custom_fields['where will this new hire attend orientation?']] = user.get_custom_field_value_text(custom_fields.key(:customOrientation))
    
    data.except!(nil)
    data.each_with_object({}) { |(key, value), hash| hash[key] = value.present? ? value.gsub('&', '&amp;') : value }
  end

  def get_single_dimension_data(field_name)
    data = super(field_name)
    data.except!(nil)
    data.each_with_object({}) { |(key, value), hash| hash[key] = value.present? ? value.gsub('&', '&amp;') : value }
  end
end
