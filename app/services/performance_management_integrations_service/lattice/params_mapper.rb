class PerformanceManagementIntegrationsService::Lattice::ParamsMapper

  def build_parameter_mappings
    {
      userName: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      formatted: { name: 'preferred_full_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      active: { name: 'state', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      externalId: { name: 'id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      startDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:lattice:attributes:1.0:User', parent_hash: 'lattice_extension' },
      birthDate: { name: 'Date of Birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:lattice:attributes:1.0:User', parent_hash: 'lattice_extension' },
      gender: { name: 'Gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:lattice:attributes:1.0:User', parent_hash: 'lattice_extension' },
      manager: { name: 'manager', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User|manager', parent_hash: 'user_extension' },
      department: { name: 'department', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User', parent_hash: 'user_extension' },
      mobile_phone_number: { name: 'mobile phone number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'phoneNumbers', parent_hash: 'phoneNumbers' }
    }
  end
end
