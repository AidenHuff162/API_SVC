class HrisIntegrationsService::Bamboo::Forward::ManageSaplingSingleDimensionData < HrisIntegrationsService::Bamboo::ManageSaplingSingleDimensionData

  def initialize(company)
    super(company)
    custom_fields.merge!({
      'customControlledSubstanceLicense(DC)' => 'controlled cubstance license (dc)',
       customDEA: 'license - dea (ca)',
      'customDEA(DC)' => 'license - dea (dc)',
      'customDEA(IL)' => 'license - dea (il)',
      'customDEA(NY)' => 'license - dea (ny)',
      'customDEA(WA)' => 'license - dea (wa)',
      customDosespotID: 'dosespot id',
      employeeNumber: 'employee #',
      legacyUserId: 'legacyUserId',
      customNPINumber: 'npi number',
      originalHireDate: 'original hire date',
      'customT-Shirt/JacketSize' => 't-shirt/jacket size',
      'employee_access' => 'self-service access',
      'payRate' => 'pay rate - currency code'
    })
  end

  def prepare_user_data(is_user_not_exists = false, is_user_terminated = false)
    data = super(is_user_not_exists, is_user_terminated)
    data[:preferred_name] = bamboo_data['nickname']

    data
  end

  def manage_profile_data user
    user.profile.github = bamboo_data['customgithubusername']
    user.profile.linkedin = bamboo_data['linkedIn']
    user.profile.about_you = bamboo_data['customWebsiteBio']
    user.save!
  end

  def manage_custom_fields(user)
    super(user)
    CustomFieldValue.set_custom_field_value(user, custom_fields['customControlledSubstanceLicense(DC)'], bamboo_data['customControlledSubstanceLicense(DC)'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customDEA], bamboo_data['customDEA'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['customDEA(DC)'], bamboo_data['customDEA(DC)'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['customDEA(IL)'], bamboo_data['customDEA(IL)'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['customDEA(NY)'], bamboo_data['customDEA(NY)'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['customDEA(WA)'], bamboo_data['customDEA(WA)'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customDosespotID], bamboo_data['customDosespotID'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:employeeNumber], bamboo_data['employeeNumber'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:legacyUserId], bamboo_data['legacyUserId'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customDosespotID], bamboo_data['customDosespotID'])
    CustomFieldValue.set_custom_field_value(user, custom_fields[:customNPINumber], bamboo_data['customNPINumber'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['customT-Shirt/JacketSize'], bamboo_data['customT-Shirt/JacketSize'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['self-service access'], bamboo_data['employee_access'])
    CustomFieldValue.set_custom_field_value(user, custom_fields['pay rate - currency code'], bamboo_data['payRate'])
  end
end
