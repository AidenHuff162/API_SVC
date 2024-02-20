class LearningAndDevelopmentIntegrationServices::Lessonly::ParamsMapper

  def build_parameter_mappings
    {
      name: { name: 'username', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      email: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      job_title: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      department: { name: 'team id', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      location: { name: 'location id', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      hire_date: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      manager_name: { name: 'manager id', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      role: { name: 'role', is_custom: false, exclude_in_create: false, exclude_in_update: true }
      # business_unit: { name: 'business unit', is_custom: true, exclude_in_create: false, exclude_in_update: false }
    }
  end
end