class LearningAndDevelopmentIntegrationServices::Kallidus::ParamsMapper

  def build_parameter_mappings(subdomain, integration = nil)
    build_default_mapping(integration)   
  end

  def build_getset_mapping
    {
      importKey: { name: 'user id', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      userName: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      firstName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      lastName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      emailAddress: { name: 'company email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      managerImportKey: { name: 'manager', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      jobTitle: { name: 'job title', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      startDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      leaveDate: { name: 'last day worked', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      isEnabled: { name: 'status', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      department: { name: 'department', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'customInformation', parent_hash: 'customInformation' }
    }
  end

  private

  def build_default_mapping integration
    integration.fetch_integration_params_mapper
  end
end