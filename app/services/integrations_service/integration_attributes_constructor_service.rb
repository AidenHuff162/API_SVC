class IntegrationsService::IntegrationAttributesConstructorService
  attr_reader :user, :params, :options

  def initialize(user, params, options)
    @user = user
    @params = params
    @options = options
  end

  def perform(integration_name)
    case integration_name.downcase 
    when 'learn_upon'
      return construct_learn_upon_attributes
    when 'lessonly'
      return construct_lessonly_attributes
    when 'namely'
      return construct_namely_attributes
    when 'deputy'
      return construct_deputy_attributes
    when 'trinet'
      return construct_trinet_attributes
    when 'fifteen_five'
      return construct_fifteen_five_attributes
    when 'peakon'
      return construct_peakon_attributes
    when 'gusto'
      return construct_gusto_attributes
    when 'lattice'
      return construct_lattice_attributes
    when 'paychex'
      return construct_paychex_attributes
    when 'kallidus_learn'
      return construct_kallidus_learn_attributes
    when 'paylocity'
      return construct_paylocity_attributes
    when 'xero'
      return construct_xero_attributes
    end
  end

  private

  def is_non_custom_data_changed?(key, params, user_attributes)
    return if params.nil?
    (['last_day_worked', 'start_date'].exclude?(key) && params[key].to_s != user_attributes[key].to_s) || (['last_day_worked', 'start_date'].include?(key) && params[key]&.to_date&.strftime("%Y-%m-%d").to_s != user_attributes[key].to_s)
  end

  def construct_learn_upon_attributes
    attributes = []
    
    ['first_name', 'last_name', 'email', 'state'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?

    return attributes.uniq
  end

  def construct_kallidus_learn_attributes
    attributes = []
    return attributes.concat(['title', 'team id', 'location id', 'manager id']) if options[:is_custom_table].present? && options[:role_information].present?
    return ['employment status'] if options[:is_custom_table].present? && options[:employment_status].present?
    
    ['first_name', 'last_name', 'email', 'start_date', 'title', 'preferred_name', 'team_id', 'location_id', 'manager_id'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?

    attributes.push('user name') if (attributes & ['first_name', 'last_name', 'preferred_name']).any?
    return [options[:name]] if options[:is_custom].present?

    return attributes.uniq
  end

  def construct_lessonly_attributes
    attributes = []
    return if options[:is_custom_table].present? && options[:role_information].blank?
    return ['title', 'team id', 'location id', 'manager id'] if options[:is_custom_table].present? && options[:role_information].present?
    
    ['first_name', 'last_name', 'preferred_name', 'email', 'title', 'team_id', 'location_id', 'start_date', 'manager_id'].each do |key|
      if is_non_custom_data_changed?(key, params, user.attributes)
        if ['first_name', 'last_name', 'preferred_name'].include?(key)
          attributes.push('username') 
        else
          attributes.push(key.tr('_', ' '))
        end 
      end
    end if options[:is_custom].blank?

    return attributes.uniq
  end

  def construct_namely_attributes
    attributes = []
    custom_field_name = []
    default_user_attributes = user.attributes.merge!(user.profile.attributes) if user.profile
    user_attributes = options[:tmp_user].present? ? options[:tmp_user] : default_user_attributes
    
    custom_field_names = options[:custom_table].custom_fields.pluck(:name) if options[:is_custom_table].present? && options[:custom_table].present?
    attributes.concat(custom_field_names) if custom_field_names.present?
    attributes.push('Employment Status') if options[:is_custom_table].present? && options[:employment_status].present?
    attributes.push('location_id', 'team_id', 'manager_id', 'title' ) if options[:is_custom_table].present? && options[:role_information].present?
    
    ['first_name', 'last_name', 'preferred_name', 'email', 'start_date', 'personal_email', 'title', 'manager_id', 'state', 'team_id', 'location_id', 'about_you', 'title', 'linkedin'].each do |key|
      if params.key?(key) && is_non_custom_data_changed?(key, params, user_attributes)
        attributes.push(key)
      end 
    end if params.present?
    if options[:is_custom].present?
      return options[:name] == 'home address' ? ['line1', 'line2', 'zip', 'city', 'state', 'country'] : [options[:name]]
    end
    attributes.push('profile image') if params.present? && params[:is_profile_image_updated].present?
    return attributes&.map(&:downcase)&.flatten&.uniq || []
  end

  def construct_deputy_attributes
    attributes = []
    
    return if options[:is_custom_table].present? && options[:compensation].blank?
    return ['salary', 'weekday pay rate', 'saturday pay rate', 'sunday pay rate', 'holiday pay rate'] if options[:is_custom_table].present? && options[:compensation].present?
    
    ['first_name', 'last_name', 'start_date', 'location_id', 'email'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?
    
    return [options[:name]] if options[:is_custom].present?

    return attributes.uniq
  end

  def construct_trinet_attributes
    attributes = []
    
    return if options[:is_custom_table].present? && options[:employment_status].blank? && options[:role_information].blank? 
    return ['title', 'team id'] if options[:is_custom_table].present? && options[:role_information].present?
    return ['employment status'] if options[:is_custom_table].present? && options[:employment_status].present?
    
    ['first_name', 'last_name', 'title', 'manager_id', 'start_date', 'email', 'team_id'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?
    
    return [options[:name]] if options[:is_custom].present? && ['flsa status', 'standard hours per week', 'job duties', 'workers comp code', 'gender', 'race/ethnicity', 'date of birth'].include?(options[:name])

    return attributes.uniq
  end

  def construct_fifteen_five_attributes
    attributes = []

    return if options[:is_custom_table].present? && options[:role_information].blank?
    return ['title', 'team_id', 'location_id', 'manager_id'] if options[:is_custom_table].present? && options[:role_information].present?
    
    ['first_name', 'last_name', 'email', 'title', 'team_id', 'location_id', 'manager_id'].each do |key|
      attributes.push(key) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?

    return attributes.uniq
  end

  def construct_peakon_attributes
    attributes = []

    return if options[:is_custom_table].present? && options[:role_information].blank? && options[:employment_status].blank?
    return ['title', 'team id', 'location id', 'manager id'] if options[:is_custom_table].present? && options[:role_information].present?
    return ['employment status', 'state'] if options[:is_custom_table].present? && options[:employment_status].present?
    
    ['first_name', 'last_name', 'state', 'email', 'title', 'team_id', 'start_date', 'location_id', 'manager_id'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?
    
    return [options[:name]] if options[:is_custom].present? && ['mobile phone number', 'gender', 'date of birth'].include?(options[:name])

    return attributes.uniq
  end

  def construct_gusto_attributes
    attributes = []
    
    return ['pay frequency', 'pay rate', 'flsa status'] if options[:is_custom_table].present? && options[:compensation].present?
    return ['title'] if options[:is_custom_table].present? && options[:role_information].present?

    ['first_name', 'last_name', 'personal_email', 'title', 'start_date', 'last_day_worked'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?
    
    return [options[:name].downcase] if options[:is_custom].present?  
    
    return attributes.uniq
  end

  def construct_lattice_attributes
    attributes = []
    return if options[:is_custom_table].present? && options[:role_information].blank?
    return ['title', 'manager_id', 'department'] if options[:is_custom_table].present? && options[:role_information].present?
    
    ['first_name', 'preferred_name', 'last_name', 'email', 'title', 'manager_id', 'state', 'start_date', 'department'].each do |key|
      attributes.push(key) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?

    return [options[:name]] if options[:is_custom].present? && ['gender', 'date of birth', 'mobile phone number'].include?(options[:name].try(:downcase))
    return attributes.uniq
  end
  
  def construct_paychex_attributes
    attributes = []

    return if options[:is_custom_table].present? && options[:employment_status].blank? && options[:role_information].blank? 
    return ['title', 'manager id'] if options[:is_custom_table].present? && options[:role_information].present?
    return ['employment status'] if options[:is_custom_table].present? && options[:employment_status].present?
    
    ['first_name', 'last_name', 'preferred_name', 'title', 'location_id', 'manager_id', 'start_date'].each do |key|
      attributes.push(key.tr('_', ' ')) if is_non_custom_data_changed?(key, params, user.attributes)
    end if options[:is_custom].blank?
    
    if ['middle name', 'tax', 'employment status', 'exemption type', 'race/ethnicity', 'date of birth', 'gender'].include?(options[:name].downcase)
      attributes = [options[:name].downcase]
    end if options[:is_custom].present?

    return attributes.uniq
  end
  
   def construct_xero_attributes
    attributes = []
    custom_field_name = []
    user_attributes = options[:tmp_user].present? ? options[:tmp_user] : user.attributes
    
    custom_field_names = options[:custom_table].custom_fields.pluck(:name) if options[:is_custom_table].present? && options[:custom_table].present?
    attributes.concat(custom_field_names) if custom_field_names.present?
    attributes.push('Employment Status') if options[:is_custom_table].present? && options[:employment_status].present?
    attributes.push('location_id', 'team_id', 'manager_id', 'title' ) if options[:is_custom_table].present? && options[:role_information].present?
    
    ['first_name', 'last_name','email', 'personal_email','xero_id','title','about_you', 'title','start_date'].each do |key|
      if params.key?(key) && is_non_custom_data_changed?(key, params, user_attributes)
        attributes.push(key)
      end 
    end if params.present?
    
    if options[:is_custom].present? && ['mobile phone number', 'home phone number', 'title', 'home address', 'date of birth', 'middle name', 'gender', 'termination reason', 'tax file number',
    'residency status', 'calculation type', 'annual salary', 'hours per week', 'rate per unit', 'account name', 'account number', 'bank name', 'bsb/sort code'].include?(options[:name])
      return options[:name] == 'home address' ? ['line1', 'line2', 'zip', 'city', 'state'] : [options[:name]]
    end

    return attributes.flatten.uniq
  end

  def construct_paylocity_attributes
    attributes = []
    paylocity_params = params
    user_attributes = options[:tmp_user].present? ? options[:tmp_user] : user.attributes
    if options[:is_custom_table].present? && options[:custom_table].present? && options[:custom_table].custom_fields.present?
      paylocity_params = options[:params].with_indifferent_access if !paylocity_params.present?
      instance = ::HrisIntegrationsService::Paylocity::Helper.new.fetch_integration(user.company, user)
      ids = instance.integration_field_mappings.pluck(:custom_field_id) & options[:custom_table].custom_fields.pluck(:id)
      attributes += (user.company.custom_fields.where(id: ids).pluck(:name).map{|item| item.try(:downcase)})
    end

    if options[:is_custom_table].present? && options[:role_information].present? && options[:tmp_user].present?
      attributes.push('department position effective data')
      attributes.push('manager id') if is_non_custom_data_changed?('manager_id', options[:tmp_user], user.attributes)
      attributes.push('title') if is_non_custom_data_changed?('title', options[:tmp_user], user.attributes)
    end

    attributes.push('status') if options[:is_custom_table].present? && options[:employment_status].present?
    attributes.push('baserate', 'salary', 'pay frequency', 'pay type', 'primary rate effective data', 'auto pay') if options[:is_custom_table].present? && options[:compensation].present?

    ['first_name', 'last_name', 'preferred_name', 'email', 'personal_email', 'title', 'manager_id', 'state', 'team_id', 'location_id'].each do |key|
      if paylocity_params.key?(key) && is_non_custom_data_changed?(key, paylocity_params, user_attributes)
        case key
        when 'state'
          key = 'status'
        when 'location_id'
          key = 'location'
        when 'team_id'
          key = 'department'
        end
        attributes.push(key.tr('_', ' '))
      end 
    end if paylocity_params.present?
    
    if options[:is_custom].present? && ['mobile phone number', 'home phone number', 'gender', 'social security number', 'federal marital status', 'home address', 'date of birth', 'ethnicity', 'middle name', 'baserate', 'salary', 'pay frequency', 'pay type', 'auto pay' ].include?(options[:name])
      return options[:name] == 'home address' ? ['line 1', 'line 2', 'zip', 'city', 'state'] : [options[:name]]
    end
    return attributes.flatten.uniq
  end
end
