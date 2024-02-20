class PerformanceManagementIntegrationsService::FifteenFive::ParamsMapper

  def build_parameter_mappings
    {
      userName: { name: 'user name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      givenName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      familyName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      work_email: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'emails', parent_hash: 'emails' },
      home_email: { name: 'personal email', is_custom: false, exclude_in_create: true, exclude_in_update: true, parent_hash_path: 'emails', parent_hash: 'emails' },
      active: { name: 'state', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      location: { name: 'location', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:15Five:2.0:User', parent_hash: '15five_extension' },
      startDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: true, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:15Five:2.0:User', parent_hash: '15five_extension' },
      department: { name: 'department', is_custom: false, exclude_in_create: true, exclude_in_update: true, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User', parent_hash: 'user_extension' },
      manager: { name: 'manager', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User|manager', parent_hash: 'user_extension' }
    }
  end
end
