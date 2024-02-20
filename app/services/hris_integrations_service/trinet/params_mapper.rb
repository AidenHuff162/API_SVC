class HrisIntegrationsService::Trinet::ParamsMapper

  def build_parameter_mappings
    {
      firstName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      lastName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      gender: { name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'biographicalInfo', parent_hash: 'biographicalInfo'},  
      ethnicity: { name: 'race/ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'biographicalInfo', parent_hash: 'biographicalInfo'},
      birthDate: { name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'biographicalInfo', parent_hash: 'biographicalInfo'},
      nationalId: { name: 'social security number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'biographicalInfo', parent_hash: 'biographicalInfo' },
      homeContact: { name: 'home contact', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'homeContact', parent_hash: 'homeContact'},
      startDate: { name: 'start date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      reasonCode: { name: 'new hire', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      employeeType: { name: 'employment status', is_custom: true, exclude_in_create: false, exclude_in_update: true, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      businessTitle: { name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: true, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      supervisorId: { name: 'manager id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      locationId: { name: 'location id', is_custom: false, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      regularTemporary: { name: 'regular/temporary', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      standardHoursPerWeek: {name: 'standard hours per week', is_custom: true, exclude_in_create: false, exclude_in_update:true, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo'},
      workEmail: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo' },
      payGroupId: { name: 'pay groups', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'employmentInfo', parent_hash: 'employmentInfo' },
      deptId: { name: 'team id', is_custom: false, exclude_in_create: false, exclude_in_update:true, parent_hash_path: 'employmentInfo|homeDepartment', parent_hash: 'employmentInfo'},
      jobCode: { name: 'job code', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'employmentInfo|compliance', parent_hash: 'employmentInfo'},
      flsaCode: {name: 'flsa status', is_custom: true, exclude_in_create: false, exclude_in_update:true, parent_hash_path: 'employmentInfo|compliance', parent_hash: 'employmentInfo'},
      workersCompCode: { name: 'workers comp code', is_custom: true, exclude_in_create: false, exclude_in_update:true, parent_hash_path: 'employmentInfo|compliance', parent_hash: 'employmentInfo'},
      jobDuties: { name: 'job duties', is_custom: true, exclude_in_create: false, exclude_in_update:true, parent_hash_path: 'employmentInfo|compliance', parent_hash: 'employmentInfo'},
      estimatedAnnualWages: {name: 'annual salary', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'payInfo', parent_hash: 'payInfo'},
      benefitClassId: {name: 'benefits group', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'timeOffAndBenefits|benefitClass', parent_hash: 'timeOffAndBenefits'},
      futureBenefitClassId: {name: 'future benefits group', is_custom: true, exclude_in_create: false, exclude_in_update:false, parent_hash_path: 'timeOffAndBenefits|benefitClass', parent_hash: 'timeOffAndBenefits'}
    }
  end

  def build_job_classification_params
    {
      effectiveDate: { name: 'effective date', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification', parent_hash: 'job_reclassification'},
      deptId: { name: 'team id', is_custom: false, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification', parent_hash: 'job_reclassification'},
      businessTitle: { name: 'title', is_custom: false, exclude_in_create: true, exclude_in_update: false, parent_hash_path: 'job_reclassification', parent_hash: 'job_reclassification'},
      employeeType: { name: 'employment status', is_custom: true, exclude_in_create: true, exclude_in_update: false, parent_hash_path: 'job_reclassification|jobReclassification', parent_hash: 'job_reclassification'},
      flsaCode: {name: 'flsa status', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification|jobReclassification', parent_hash: 'job_reclassification'},
      standardHours: {name: 'standard hours per week', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification|jobReclassification', parent_hash: 'job_reclassification'},
      jobDuties: { name: 'job duties', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification|workComp', parent_hash: 'job_reclassification'},
      workCompCode: { name: 'workers comp code', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'job_reclassification|workComp', parent_hash: 'job_reclassification0'}
    }
  end

  def build_personal_params
    {
      effectiveDate: { name: 'effective date', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'personal', parent_hash: 'personal'},
      gender: { name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'personal', parent_hash: 'personal'},  
      ethnicity: { name: 'race/ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'personal', parent_hash: 'personal'},
      birthDate: { name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'personal', parent_hash: 'personal'},
      country: { name: 'country', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'personal', parent_hash: 'personal'}
    }
  end


  def build_name_params
    {
      effectiveDate: { name: 'effective date', is_custom: true, exclude_in_create: true, exclude_in_update:false, parent_hash_path: 'name', parent_hash: 'name'},
      firstName: { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      lastName: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' },
      nameType: { name: 'name type', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'name', parent_hash: 'name' }
    }
  end
end