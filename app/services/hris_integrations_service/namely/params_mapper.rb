class HrisIntegrationsService::Namely::ParamsMapper

  def build_v2_parameter_mapping 
    {
      social_security_number: {name: 'ssn', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      federal_marital_status: {name: 'marital_status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      date_of_birth: {name: 'dob', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      gender: {name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact_name: {name: 'emergency_contact', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact_number: {name: 'emergency_contact_phone', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact_relationship: {name: 'emergency_contact_relationship', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      race_ethnicity: {name: 'ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      home_phone_number: {name: 'home_phone', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      mobile_phone_number: {name: 'mobile_phone', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      line_1: {name: 'address1', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      line_2: {name: 'address2', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      city: {name: 'city', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      zip: {name: 'zip', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      country: {name: 'country_id', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      state: {name: 'state_id', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      about_you: {name: 'bio', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '',is_profile_field: true },
      email: {name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      personal_email: {name: 'personal_email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      first_name: {name: 'first_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      last_name: {name: 'last_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      start_date: {name: 'start_date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      title: {name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, pre_parent_hash_path: 'links', parent_hash_path: 'job_title', parent_hash: '' },
      namely_last_changed: {name: 'updated_at', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      preferred_name: {name: 'preferred_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      employment_status: {name: 'title', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'employee_type', parent_hash: '' },
      onboard_email: {name: 'onboard_email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_1stdibs_saplingapp_io 
    {
      department_number: {name: 'department_number1', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_cruise_saplingapp_io 
    {
      shirt_size: {name: 'shirt_size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      food_allergies: {name: 'food_allergies', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      have_you_ever_been_employed_by_gm_and_or_assigned_a_gmin_or_gmid: {name: 'have_you_ever_been_employed_by_gm_and_or_assigned_a_gmin_or_gmid', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      level: {name: 'level', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      band_title: {name: 'job_family', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      gender_pronouns: {name: 'preferred_gender_pronoun', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      veteran_status: {name: 'veteran_status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      disability_status: {name: 'disability_status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_handshake_saplingapp_io
    {
      apparel_size: {name: 'apparel_size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      ethnicity: {name: 'ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      marital_status: {name: 'marital_status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_greenlight_saplingapp_io 
    {
      leader: {name: 'leader', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      parking_election: {name: 'parking_election', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      t_shirt_size: {name: 't_shirt_size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      gender_identity: {name: 'gender_identity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_circleci_saplingapp_io 
    {
      sex: {name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      marital_status: {name: 'marital_status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def build_parameter_for_kayak_saplingapp_io 
    {
      employment_status: {name: 'time_type_ft_pt', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_parameters 
    {
      first_name: {name: 'first_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      employee_type: {name: 'employment status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      last_name: {name: 'last_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      start_date: {name: 'start_date', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      email: {name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      personal_email: {name: 'personal_email', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      job_title: {name: 'title', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      location: {name: 'location_id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      reports_to: {name: 'manager_id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      team: {name: 'team_id', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      address1: {name: 'line1', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      address2: {name: 'line2', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      zip: {name: 'zip', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      city: {name: 'city', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      country_id: {name: 'country', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      state_id: {name: 'state', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: 'home', parent_hash: 'home', source: 'namely' },
      mobile_phone: {name: 'mobile phone number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      home_phone: {name: 'home phone number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      ssn: {name: 'social security number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact: {name: 'emergency contact name', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact_phone: {name: 'emergency contact number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      emergency_contact_relationship: {name: 'emergency contact relationship', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      dob: {name: 'date of birth', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      bio: {name: 'about_you', is_profile_field: true, is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      marital_status: {name: 'federal marital status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      gender: {name: 'gender', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      ethnicity: {name: 'race/ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '', source: 'namely' },
      preferred_name: {name: 'preferred_name', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      image: {name: 'profile image', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_for_handshake_saplingapp_io 
    {
      marital_status: {name: 'marital status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      ethnicity: {name: 'ethnicity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      apparel_size: {name: 'apparel size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      federal_filing_marital_status: {name: 'federal: filing marital status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      federal_additonal_withholding: {name: 'federal: additional withholding', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      federal_exemptions_requested: {name: 'federal: exemptions requested', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      federal_withholding_additional_type: {name: 'federal withholding additional type', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      state_filing_marital_status: {name: 'state: filing marital status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      state_additional_withholding: {name: 'state: additional withholding', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      state_exemptions_requested: {name: 'state: exemptions requested', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      routing_number: {name: 'direct deposit - account routing number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      account_number: {name: 'direct deposit - account number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      type_of_account: {name: 'type of account', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      career_level: {name: 'career level', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
    }
  end

  def push_users_for_circleci_saplingapp_io
    {
      marital_status: {name: 'marital status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      gender: {name: 'sex', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_for_greenlight_saplingapp_io
    {
      team: {name: '', is_custom: false, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      leader: {name: 'leader', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      parking_election: {name: 'parking election', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      t_shirt_size: {name: 't-shirt size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      gender_identity: {name: 'gender identity', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_for_cruise_saplingapp_io
    {
      shirt_size: {name: 'shirt size', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      food_allergies: {name: 'food allergies', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      emergency_contact_relationship: {name: 'emergency contact relationship', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      emergency_contact_email: {name: 'emergency contact email', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      have_you_ever_been_employed_by_gm_and_or_assigned_a_gmin_or_gmid: {name: 'have you ever been employed by gm and/or assigned a gmin or gmid?', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      level: {name: 'level', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      job_family: {name: 'band title', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      preferred_gender_pronoun: {name: 'gender pronouns', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      veteran_status: {name: 'veteran status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      do_you_consider_yourself_a_member_of_the_lesbian_gay_bisexual_transgender_queer_questioning_intersex_and_or_asexual_lgbtq_community: {name: 'do you consider yourself a member of the lesbian, gay, bisexual, transgender, queer, questioning, intersex, and/or asexual, lgbtq community?', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      disability_status: {name: 'disability status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_for_1stdibs_saplingapp_io 
    {
      department_number1: {name: 'department number', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end

  def push_users_for_kayak_saplingapp_io
    {
      image: {name: '', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      employee_type: {name: '', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' },
      time_type_ft_pt: {name: 'employment status', is_custom: true, exclude_in_create: false, exclude_in_update: false, parent_hash_path: '', parent_hash: '' }
    }
  end
end
