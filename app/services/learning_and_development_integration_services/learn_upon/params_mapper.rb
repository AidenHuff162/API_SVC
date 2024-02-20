class LearningAndDevelopmentIntegrationServices::LearnUpon::ParamsMapper

  def build_parameter_mappings
    {
      first_name:  { name: 'first name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      last_name: { name: 'last name', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      email: { name: 'email', is_custom: false, exclude_in_create: false, exclude_in_update: false },
      account_expires: { name: 'last day worked', is_custom: false, true: false, exclude_in_update: false }, 
      enabled: { name: 'state', is_custom: false, exclude_in_create: true, exclude_in_update: false },
      password: { name: 'password', is_custom: false, exclude_in_create: false, exclude_in_update: true },
      user_type: { name: 'role', is_custom: false, exclude_in_create: false, exclude_in_update: true },
      change_password_on_first_login: { name: 'change password on first login', is_custom: false, exclude_in_create: false, exclude_in_update: true }
    }
  end
end