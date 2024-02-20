class HrisIntegrationsService::Gusto::ParamsMapper
  
  def build_parameter_mappings
    {
      first_name: {name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'user', parent_hash: 'user' },
      last_name: {name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'user', parent_hash: 'user' },
      email: { name: 'personal email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'user', parent_hash: 'user' },
      ssn: {name: 'social security number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'user', parent_hash: 'user'},
      date_of_birth: {name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'user', parent_hash: 'user'},
      home_address: {name: 'home address', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home_address', parent_hash: 'home_address' },
      title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'jobs', parent_hash: 'jobs'}, 
      hire_date: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'jobs', parent_hash: 'jobs'}, 
      payment_unit: { name: 'pay frequency', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'compensations', parent_hash: 'compensations'},
      rate: { name: 'pay rate', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'compensations', parent_hash: 'compensations'},
      flsa_status: { name: 'flsa status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'compensations', parent_hash: 'compensations'},
      effective_date: { name: 'last day worked', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'terminate', parent_hash: 'terminate'},
    }
  end
end
