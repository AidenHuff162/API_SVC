class PerformanceManagementIntegrationsService::Peakon::ParamsMapper

  def build_parameter_mappings
    {
      givenName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      familyName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      formatted: { name: 'full name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      userName: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      phoneNumbers: { name: 'mobile phone number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'phoneNumbers', parent_hash: 'phoneNumbers' },
      active: { name: 'state', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      Title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Gender: { name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Department: { name: 'team id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Location: { name: 'location id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Employment_Status: { name: 'employment status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Date_of_Birth: { name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Start_Date: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Manager: { name: 'manager id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Termination_Date: { name: 'termination date', is_custom: false, exclude_in_create: true, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' },
      Termination_Type: { name: 'termination type', is_custom: false, exclude_in_create: true, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:peakon:2.0:User', parent_hash: 'peakon_extension' }
    }
  end
end