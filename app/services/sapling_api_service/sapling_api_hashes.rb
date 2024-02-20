module SaplingApiService
  module SaplingApiHashes
    DEFAULT_API_FIELDS_ID = %w[first_name last_name preferred_name job_title job_tier manager location
                               department start_date termination_date status last_day_worked company_email personal_email
                               profile_photo buddy termination_type eligible_for_rehire about linkedin twitter github].freeze
    FILTERS = %w[employment_status limit page email].freeze

    DEFAULT_FIELDS_MAPPER = {
      ui: { user_attr: 'id', hash_key: 'id', association: '' },
      fn: { user_attr: 'first_name', hash_key: 'first_name', association: '' },
      ln: { user_attr: 'last_name', hash_key: 'last_name', association: '' },
      sd: { user_attr: 'start_date', hash_key: 'start_date', association: '' },
      pn: { user_attr: 'preferred_name', hash_key: 'preferred_name', association: '' },
      pe: { user_attr: 'personal_email', hash_key: 'personal_email', association: '' },
      ce: { user_attr: 'email', hash_key: 'company_email', association: '' },
      jt: { user_attr: 'title', hash_key: 'job_title', association: '' },
      tt: { user_attr: 'termination_type', hash_key: 'termination_type', association: '' },
      efr: { user_attr: 'eligible_for_rehire', hash_key: 'eligible_for_rehire', association: '' },
      td: { user_attr: 'termination_date', hash_key: 'termination_date', association: '' },
      ltw: { user_attr: 'last_day_worked', hash_key: 'last_day_worked', association: '' },
      st: { user_attr: 'state', hash_key: 'state', association: '' },
      pp: { user_attr: 'original_picture', hash_key: 'profile_photo', association: '' },

      man: { user_attr: 'guid', hash_key: 'manager', association: 'manager' },
      bdy: { user_attr: 'guid', hash_key: 'buddy', association: 'buddy' },
      loc: { user_attr: 'name', hash_key: 'location', association: 'location' },
      dpt: { user_attr: 'name', hash_key: 'department', association: 'team' },

      abt: { user_attr: 'about_you', hash_key: 'about', association: 'profile' },
      gh: { user_attr: 'github', hash_key: 'github', association: 'profile' },
      twt: { user_attr: 'twitter', hash_key: 'twitter', association: 'profile' },
      lin: { user_attr: 'linkedin', hash_key: 'linkedin', association: 'profile' },

      wp: { user_attr: 'working_pattern_id', hash_key: 'working_pattern', association: '' }
    }.freeze
  end
end
