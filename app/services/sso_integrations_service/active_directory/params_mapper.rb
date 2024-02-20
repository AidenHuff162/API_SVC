class SsoIntegrationsService::ActiveDirectory::ParamsMapper

  def build_parameter_mappings
    {
      accountEnabled: { name: 'state', is_custom: false, ad_type: 'boolean', exclude_in_create: false },
      givenName: { name: 'first name', is_custom: false, ad_type: 'string', exclude_in_create: false },
      surname: { name: 'last name', is_custom: false, ad_type: 'string', exclude_in_create: false },
      # preferredName: { name: 'preferred name', is_custom: false, ad_type: 'string', exclude_in_create: true },
      # hireDate: { name: 'start date', is_custom: false, ad_type: 'date_time', exclude_in_create: true },
      displayName: { name: 'display name', is_custom: false, ad_type: 'string', exclude_in_create: false },
      userType: { name: 'user type', is_custom: false, ad_type: 'string', exclude_in_create: false },
      userPrincipalName: { name: 'email', is_custom: false, ad_type: 'string', exclude_in_create: false },
      mailNickname: { name: 'mail nick name', is_custom: false, ad_type: 'string', exclude_in_create: false },
      jobTitle: { name: 'title', is_custom: false, ad_type: 'string', exclude_in_create: false },
      department: { name: 'team', is_custom: false, ad_type: 'string', exclude_in_create: false },
      officeLocation: { name: 'location', is_custom: false, ad_type: 'string', exclude_in_create: false },
      mobilePhone: { name: 'mobile phone number', is_custom: true, ad_type: 'string', exclude_in_create: false },
      # birthday: { name: 'date of birth', is_custom: true, ad_type: 'date_time', exclude_in_create: true },
      manager: { name: 'manager', is_custom: false, ad_type: 'object', exclude_in_create: true }
    }
  end
end