class HrisIntegrationsService::Bamboo::Forward::ManageBambooSingleDimensionData < HrisIntegrationsService::Bamboo::ManageBambooSingleDimensionData

  def initialize(user)
    super(user)
    custom_fields.merge!({
      'controlled cubstance license (dc)' => 'customControlledSubstanceLicense(DC)',
      'license - dea (ca)' => :customDEA,
      'license - dea (dc)' => 'customDEA(DC)',
      'license - dea (il)' => 'customDEA(IL)',
      'license - dea (ny)' => 'customDEA(NY)',
      'license - dea (wa)' => 'customDEA(WA)',
      'dosespot id' => :customDosespotID,
      'employee #' => :employeeNumber,
      'legacyUserId' => :customlegacyUserId,
      'npi number' => :customNPINumber,
      'original hire date' => :originalHireDate,
      't-shirt/jacket size' => 'customT-Shirt/JacketSize',
      'self-service access' => 'employee_access',
      'pay rate - currency code' => 'payRate'
    })
  end

  def prepare_user_data
    data = super
    data[:nickname] = user.preferred_name
    data[:terminationDate] = user.termination_date
    
    data
  end

  def prepare_profile_data
    data = {}
    data[:customgithubusername] = user.profile.github
    data[:linkedIn] = user.profile.linkedin
    data[:customWebsiteBio] = user.profile.about_you

    data
  end


  def prepare_custom_data
    data = super

    data[custom_fields['Controlled Substance License (DC)']] = user.get_custom_field_value_text(custom_fields.key('customControlledSubstanceLicense(DC)'))
    data[custom_fields['license - dea (ca)']] = user.get_custom_field_value_text(custom_fields.key(:customDEA))
    data[custom_fields['license - dea (dc)']] = user.get_custom_field_value_text(custom_fields.key('customDEA(DC)'))
    data[custom_fields['license - dea (il)']] = user.get_custom_field_value_text(custom_fields.key('customDEA(IL)'))
    data[custom_fields['license - dea (ny)']] = user.get_custom_field_value_text(custom_fields.key('customDEA(NY)'))
    data[custom_fields['license - dea (wa)']] = user.get_custom_field_value_text(custom_fields.key('customDEA(WA)'))
    data[custom_fields['dosespot id']] = user.get_custom_field_value_text(custom_fields.key(:customDosespotID))
    data[custom_fields['employee #']] = user.get_custom_field_value_text(custom_fields.key(:employeeNumber))
    data[custom_fields['legacyUserId']] = user.get_custom_field_value_text(custom_fields.key(:legacyUserId))
    data[custom_fields['NPI Number']] = user.get_custom_field_value_text(custom_fields.key(:customNPINumber))
    data[custom_fields['original hire date']] = user.get_custom_field_value_text(custom_fields.key(:originalHireDate))
    data[custom_fields['t-shirt/jacket size']] = user.get_custom_field_value_text(custom_fields.key('customT-Shirt/JacketSize'))
    data[custom_fields['self-service access']] = user.get_custom_field_value_text(custom_fields.key('employee_access'))
    data[custom_fields['pay rate - currency code']] = user.get_custom_field_value_text(custom_fields.key('payRate'))
    data.except!(nil)
  end
  
  def get_single_dimension_data(field_name)
    data = super(field_name)
    data.except!(nil)
    data.each_with_object({}) { |(key, value), hash| hash[key] = value.present? ? value.gsub('&', '&amp;') : value }
  end
end
