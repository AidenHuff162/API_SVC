class HrisIntegrationsService::Paychex::ParamsMapper

  def build_parameter_mappings
		{
		  givenName:  { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
		  middleName: { name: 'middle name', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
		  familyName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
		  preferredName: { name: 'preferred name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' }, 
		  title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'job', parent_hash: 'job' },
		  hireDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
		  workerType: { name: 'worker type', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
		  legalId: { name: 'tax', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'legalId', parent_hash: 'legalId' },
		  employmentType: { name: 'employment status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
		  exemptionType: { name: 'exemption type', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
		  ethnicityCode: { name: 'race/ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
		  birthDate: { name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
	    sex: { name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: '', parent_hash: '' },
	    locationId: { name: 'location id', is_custom: false, exclude_in_create: false, exclude_in_update:false, parent_hash_path: '', parent_hash: '' },
		  workerId: { name: 'manager id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'supervisor', parent_hash: 'supervisor' }
		}
  end
end