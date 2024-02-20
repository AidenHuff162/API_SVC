class HrisIntegrationsService::Namely::Helper
  delegate :fetch_profiles, :fetch_groups, :get_profile_image, :update_profile, to: :endpoint_service
  
  def fetch_integration(company, user=nil)
    if user.present?
      company.integration_instances.where(api_identifier: 'namely').find_each do |instance|
        return instance if can_integrate_profile?(instance, user)
      end
    else
      company.integration_instances.where(api_identifier: 'namely').first  
    end
  end

  def is_namely_credentials?(credentials)
    credentials.present? && credentials.company_url.present? && credentials.permanent_access_token.present?
  end

  def log_it(action, request, response, status, company)
    LoggingService::IntegrationLogging.new.create(company, 'Namely', action, request, response, status)
  end
 
  def is_integration_valid?(integration)
    integration.present? && integration.company_url.present? && integration.permanent_access_token.present?
  end

  def can_integrate_profile?(integration, user)
    return unless integration.present? && integration.filters.present?
      
    filter = integration.filters
    (apply_to_location?(filter, user) && apply_to_team?(filter, user) && apply_to_employee_type?(filter, user))
  end

  def create_loggings(company, action, status, request='No Request', response = {})
    LoggingService::IntegrationLogging.new.create(
      company,
      'Namely',
      action,
      request,
      response,
      status
    )
  end

  def apply_to_location?(filter, user)
    location_ids = filter['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filter, user)
    team_ids = filter['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filter, user)
    employee_types = filter['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end
  
  def log_statistics(action, company)
    if action == 'success'
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_success_hris_statistics(company)
    else
      ::RoiManagementServices::IntegrationStatisticsManagement.new.log_failed_hris_statistics(company)
    end
  end


  def get_effective_date(user, table_type)
    table = user.company.custom_tables.find_by(custom_table_property: table_type)
    return unless table.present?

    ctus = userassign_with_relations.custom_table_user_snapshots.where(state: :applied, custom_table_id: table.id).take
    return unless ctus.present?
    
    field = table.custom_fields.find_by(name: 'Effective Date')

    return unless field.present?

    return ctus.custom_snapshots.where(custom_field_id: field.id).take.try(:custom_field_value).to_s
  end

  def create_user_params(profile, company, parameter_mappings, namely, namely_credentials)
    custom_fields_data = {}
    profile_data = {}
    user_params = {
      updated_from: 'integration',
    }
    parameter_mappings.each do |key, value|
      next if ["", nil].include?(value[:name])
      if value[:pre_parent_hash_path].present?
        next if key.to_s == 'title' && is_company_using_custom_tables(company)
        user_params["#{key}"]=profile["#{value[:pre_parent_hash_path]}"]["#{value[:parent_hash_path]}"]["#{value[:name]}"] rescue nil
      elsif key.to_s == 'onboard_email'
        user_params["#{key}"] = profile["#{value[:name]}"].present? ? 'personal' : 'company'
      elsif value[:is_profile_field].present?
        profile_data["#{key}"]=profile["#{value[:name]}"]
      elsif value[:is_custom]
        temp = {}
        temp["#{key}"] = value
        custom_fields_data.merge!(temp)
      else
        user_params["#{key}"] = profile["#{value[:name]}"]
      end
    end

    namely_groups = get_namely_groups(namely_credentials)
    groups = profile['links']['groups'] rescue nil
    if groups.present?
      location_id = nil
      team_id = nil

      groups.each do |group|
        group_type = get_group_type(group['id'], namely_groups)
        if group_type.eql?(company.department_mapping_key.downcase) && !is_company_using_custom_tables(company)
          team_id = find_team_id(group['name'], company)
        elsif group_type.eql?(company.location_mapping_key.downcase) && !is_company_using_custom_tables(company)
          location_id = find_location_id(group['name'], company)
        else
          field = get_custom_group(group['id'], company)
          if field.present?
            field_key = field&.name.downcase.gsub(' ', '_')
            value = {name: '', is_custom: false, exclude_in_create: false, exclude_in_update: false, pre_parent_hash_path: 'links', parent_hash_path: 'groups', parent_hash: '', value: '' }
            value[:value] = group['name']
            custom_fields_data["#{field_key}"] = value
          end
        end
      end

      user_params[:location_id] = location_id
      user_params[:team_id] = team_id
    end

    # profile_data.updating_integration.update_column(:last_sync, DateTime.now) if user_params.updating_integration

    user_params = user_params&.reject { |k,v| !is_value_present?(v) }
    profile_data = profile_data&.reject { |k,v| !is_value_present?(v) }

    data_returned = {
      user_params: user_params,
      profile_data: profile_data,
      custom_fields_data: custom_fields_data
    }

    return data_returned
  end

  def update_custom_fields(custom_fields_data, user, company, profile, namely_credentials, namely) 
    changed_custom_fields = []
    old_home_address_value = user.get_custom_field_value_text("Home Address") rescue nil
    country = get_namely_country_name(profile['home']['country_id'], namely) rescue nil
    state = get_namely_state_name(profile['home']['country_id'], profile['home']['state_id'], country, namely)
    address = { country: country, state: state }
    custom_fields_data.each do |key, value|
      next if company.domain == "cruise.saplingapp.io" && value[:source].present? && user.created_by_source == value[:source]
      if state && ['line_1', 'line_2', 'city', 'zip', 'country', 'state'].include?(key.to_s)
        old_value = user.get_custom_field_value_text("Home Address") rescue nil
        address_value = profile["#{value[:parent_hash_path]}"]["#{value[:name]}"]
        if ['state', 'country'].include?(key.to_s)
          address_value = address[key.to_sym]
        end
        set_sub_custom_field_value(user, 'Home Address', key.to_s, address_value) rescue nil
        existance = changed_custom_fields.find {|x| x[:name] == "Home Address"}
        changed_custom_fields.push({name: "Home Address", old_value: old_value}) if !existance.present?
      elsif key.to_s == 'employment_status' && !is_company_using_custom_tables(company)
        custom_field = CustomField.where("name ILIKE ? ", key.to_s.gsub(' ', '_').gsub('-', '_')).take 
        old_value = user.get_custom_field_value_text(custom_field&.name) rescue nil
        if company.subdomain.eql?('kayak')
          set_custom_field_value(user,custom_field&.name, map_employment_type(profile["#{value[:name]}"]), company, namely_credentials) rescue nil
        else
          set_custom_field_value(user,custom_field&.name, map_employment_type(profile["#{value[:parent_hash_path]}"]["#{value[:name]}"]), company, namely_credentials) rescue nil
        end
        changed_custom_fields.push({name: custom_field&.name, old_value: old_value})            
      else
        field_name = key.to_s
        custom_field = CustomField.where("name ILIKE ? ", field_name).take 
        old_value = user.get_custom_field_value_text(custom_field&.name) rescue nil
        field_value = value[:value].present? ? value[:value] : profile["#{value[:name]}"]
        set_custom_field_value(user,custom_field&.name, field_value, company, namely_credentials)  rescue nil
        changed_custom_fields.push({name: custom_field&.name, old_value: old_value})
      end
    end
    create_field_history_for_home_address(user, old_home_address_value, company, namely_credentials)
    changed_custom_fields
  end

  def assign_manager_to_user(user, profile, company)
    if profile['reports_to'][0]['id'] != 'no_guid' && !is_company_using_custom_tables(company)
      task_count = 0

      if user && user.manager
        task_count = TaskUserConnection.joins(:task).where(tasks: {task_type: 2}, user_id: user.id, owner_id: user.manager.id, state: 'in_progress' ).count
      end

      manager = company.users.find_by_namely_id(profile['reports_to'][0]['id'])

      if manager
        if task_count > 0
          user.flush_managed_user_count(user.manager_id, manager.id)
          user.update_column(:manager_id, manager.id)
        elsif manager.present?
          user.manager_id = manager.id
          user.save!
        end
      end
    end   
  end

  def is_user_exists?(namely_id, company)
    company.users.exists?(namely_id: namely_id)
  end

  def is_user_updated?(namely_id, namely_last_changed, company)
    company.users.exists?(namely_id: namely_id, namely_last_changed: namely_last_changed)
  end

  def map_employment_type(employment_type)
    type = employment_type.downcase.gsub(' ', '_').gsub('-', '_') rescue nil
    if (type == 'part_time' || type == 'full_time' || type == 'contractor' || type == 'intern' || type == 'freelance')
      return type
    else
      return nil
    end
  end

  def get_group_type(group_type, groups)
    groups.select { |group| group['id'].eql?(group_type) }.first['type'].downcase rescue nil
  end

  def find_location_id(location_name, company)
    company.locations.select { |location| location.name.downcase.eql?(location_name.downcase.strip) }.first.id rescue nil
  end

  def find_team_id(team_name, company)
    company.teams.select { |team| team.name.downcase.eql?(team_name.downcase.strip) }.first.id rescue nil
  end

  def get_custom_field(user, field_name)
    user.company.custom_fields.find_by('name ILIKE ?', field_name)
  end

  def set_custom_field_value(user, field_name, custom_field_value, company, namely_credentials)
    return unless is_value_present?(custom_field_value)
    custom_field = get_custom_field(user, field_name)
    if custom_field.present?
      user_custom_field_value = custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
      if custom_field.field_type == 'short_text' || custom_field.field_type == 'long_text' || custom_field.field_type == 'social_security_number' || custom_field.field_type == 'date' || custom_field.field_type == 'simple_phone' || custom_field.field_type == 'number'
        user_custom_field_value.value_text = custom_field_value
      elsif custom_field.field_type != 'address'
        user_custom_field_value.custom_field_option_id = custom_field.custom_field_options.find_by('option ILIKE ?', custom_field_value).id rescue nil
      end
      user_custom_field_value.save!
      user_custom_field_value.updating_integration = namely_credentials
    end
  end

  def get_namely_country_name(country_id = nil, namely)
    country = namely.countries.find(country_id).name rescue nil
    Country.exists?(name: country) ? country : 'Other'
  end

  def set_sub_custom_field_value(user, field_name, sub_field_name, custom_field_value)
    return unless is_value_present?(custom_field_value)
    custom_field = get_custom_field(user, field_name)
    if custom_field.present?
      sub_custom_field = custom_field.sub_custom_fields.find_by('name ILIKE ?', sub_field_name)
      if sub_custom_field.present? && sub_custom_field.field_type == 'short_text'
        user_sub_custom_field_value = sub_custom_field.custom_field_values.find_or_initialize_by(user_id: user.id)
        user_sub_custom_field_value.value_text = custom_field_value
        user_sub_custom_field_value.save!
      end
    end
  end

  def get_namely_state_name(country_id = nil, state_id = nil, country_name = nil, namely)
    subdivision = namely.countries.find(country_id).links['subdivisions'].select { |subdivision| subdivision['id'].downcase.eql?(state_id.downcase) } rescue nil
    subdivision.first['name'] rescue nil
  end

  def get_custom_group(namely_id, company)
    company.custom_fields.joins(:custom_field_options).where(custom_field_options: {namely_group_id: namely_id}).first
  end

  def create_field_history_for_home_address(user, old_home_address_value, company, namely_credentials)
    begin
      current_home_address_value = user.get_custom_field_value_text('Home Address')
      return unless current_home_address_value != old_home_address_value
      custom_field = company.custom_fields.where(name: 'Home Address').take
      user.field_histories.create!(field_name: custom_field.name.titleize, custom_field_id: custom_field.id, new_value: current_home_address_value, integration_instance_id: namely_credentials.id, field_type: "text")
    rescue Exception => e
      log_it("Namely pull - Creating Field History for home address user - #{user.id} - Failure", {request: 'create field history while namely pull'}, {error: e.message}, 500, company)
    end
  end

  def establish_connection(integration)
    namely = nil
    if is_namely_credentials?(integration)
      namely = ::Namely::Connection.new(
        access_token: integration.permanent_access_token,
        subdomain: integration.company_url
      )
    end
    namely
  end

  def get_namely_groups(integration)
    groups = []
    if is_namely_credentials?(integration)
      groups = fetch_groups(integration)
      groups = JSON.parse(groups.body)
      groups = groups['groups'] rescue nil
    end
    groups
  end

  def get_namely_profiles(page, integration)
    profiles = { profiles: [] }
    if is_namely_credentials?(integration)
      sleep 2
      profiles = fetch_profiles(integration, page)
      profiles = JSON.parse(profiles.body) if profiles && profiles.code == 200
    end
    profiles
  end

  def endpoint_service
    HrisIntegrationsService::Namely::Endpoint.new
  end

  def send_notifications(user, reason = nil)
    message = ''
    if reason.present?
      message = I18n.t("history_notifications.hris_not_sent", name: user.full_name, hris: "Namely", reason: reason.to_s)
      History.create_history({
        company: user.company,
        user_id: user.id,
        description: message,
        attached_users: [user.id],
        created_by: History.created_bies[:system],
        integration_type: History.integration_types[:namely],
        is_created: History.is_createds[:unsuccessful],
        event_type: History.event_types[:integration]
      })
    else
      message = I18n.t("history_notifications.hris_sent", name: user.full_name, hris: "Namely")
      History.create_history({
        company: user.company,
        user_id: user.id,
        description: message,
        attached_users: [user.id],
        created_by: History.created_bies[:system],
        integration_type: History.integration_types[:namely],
        event_type: History.event_types[:integration]
      })
    end

    SlackNotificationJob.perform_later(user.company.id, {
      username: user.full_name,
      text: message
    })
  end

  def get_career_level_code(career_level)
    case career_level.downcase
    when 'ceo'
      return 'CEO'
    when '12 - c-level team'
      return '12 - C-level Team'
    when '11 - svp team'
      return '11 - SVP Team'
    when '10 - vp team'
      return '10 - VP Team'
    when '9 - senior advisor / senior director team'
      return '9 - Senior Advisor / Senior Director Team'
    when '8 - advisor / director team'
      return '8 - Advisor / Director Team'
    when '7 - expert team'
      return '7 - Expert Team'
    when '6 - skilled team'
      return '6 - Skilled Team'
    when '5 - experienced team'
      return '5 - Experienced Team'
    when '4 - associate team'
      return '4 - Associate Team'
    when '3 - entry team'
      return '3 - Entry Team'
    else
      return nil
    end
  end

  def get_gender_code(gender)
    case gender.downcase
    when 'male'
      return 'Male'
    when 'female'
      return 'Female'
    when 'not specified'
      return 'Not specified'
    else
      return nil
    end
  end

  def get_namely_profile_image_id(user, company, namely_credentials)
    if user.profile_image.present? && user.profile_image.file.present? && user.profile_image.file.url.present?
      downloaded_image = MiniMagick::Image.open(user.profile_image.file.url)

      require 'fileutils'
      unless File.directory?("#{Rails.root}/tmp/profile_image/#{company.id}/")
        FileUtils.mkdir_p("#{Rails.root}/tmp/profile_image/#{company.id}/")
      end
      profile_image = downloaded_image.write("#{Rails.root}/tmp/profile_image/#{company.id}/profile-#{user.id}.jpg")
    end

    image = get_profile_image(namely_credentials, company, user.id)
    image = JSON.parse(image.body) rescue nil
    image['files'][0]['id'] rescue nil
  end

  def get_custom_field_value_for_namely_group_type(field_name, company, user)
    custom_field = company.custom_fields.find_by('name ILIKE ?', field_name)
    if custom_field.present?
      custom_field_value = user.custom_field_values.find_by(custom_field_id: custom_field.id)
      custom_field_option = CustomFieldOption.find(custom_field_value.custom_field_option_id) rescue nil
      if custom_field_option.present? && custom_field_option.namely_group_type.present?
        return custom_field_option
      end
    end
    return nil
  end

  def get_namely_job_title(user_job_title, namely)
    namely.job_titles.all.select { |job_title| job_title.title.downcase.eql?(user_job_title.downcase) }.first.id rescue nil
  end

  def get_federal_marital_status_code(federal_marital_status)
    case federal_marital_status.downcase
    when 'single'
      return 'Single'
    when 'married'
      return 'Married'
    when 'civil partnership'
      return 'Civil Partnership'
    when  'separated'
      return 'Separated'
    when 'divorced'
      return 'Divorced'
    when 'head of household'
      return 'Head of Household'
    when 'married use single rate'
      return 'Married use Single Rate'
    else
      return nil
    end
  end

  def get_employee_type(employee_type, user)
    if user.company.subdomain.eql?('kayak')
      type = employee_type.titleize.gsub(' ','-') rescue nil
    else
      type = employee_type.gsub('_',' ').titleize rescue nil
    end
  end

  def get_federal_withholding_additional_type_code(federal_withholding_additional_type)
    case federal_withholding_additional_type.downcase
    when 'dollar'
      return 'Dollar'
    when 'percent'
      return 'Percent'
    else
      return nil
    end
  end

  def get_type_of_account_code(type_of_account)
    case type_of_account.downcase
    when 'checking'
      return 'Checking'
    when 'savings'
      return 'Savings'
    else
      return nil
    end
  end

  def get_namely_country_id(country_name = nil, namely)
    namely.countries.all.select { |country| country.name.downcase.eql?(country_name.downcase) }.first.id rescue nil
  end

  def get_namely_state_id(country_id = nil, state = nil, namely)
    namely.countries.find(country_id).links['subdivisions'].select { |subdivision| (subdivision['id'].downcase.eql?(state.downcase) || subdivision['name'].downcase.eql?(state.downcase)) }.first['id'] rescue nil
  end

  def get_home_address(field_name, user, namely)
    address = user.get_custom_field_value_text(field_name, true)
    if address.present?
      address[:country] = get_namely_country_id(address[:country], namely)
      address[:state] = get_namely_state_id(address[:country], address[:state], namely)
    end
    return address
  end

  def find_team(team_id, company)
    company.teams.find(team_id) if team_id.present?
  end

  def find_location(location_id, company)
    company.locations.find(location_id) if location_id.present?
  end

  def update_namely_profile(data, namely_credentials, user)
    response = nil
    if is_namely_credentials?(namely_credentials)
      response = update_profile(namely_credentials, data, user)
    end
    response
  end

  def is_company_using_custom_tables(company)
    company.try(:is_using_custom_table)
  end

  def is_value_present?(value)
    ['', nil].exclude?(value)
  end
end
