class HrisIntegrationsService::Paylocity::UpdatePaylocityProfileInSapling

  attr_reader :company, :integration, :sapling_keys, :parameter_mappings

  delegate :create_loggings, :can_integrate_profile?, :map_sapling_state,
    :map_sapling_gender, :map_sapling_marital_status, :map_sapling_employee_type,
    :map_sapling_manager, :map_sapling_pay_frequency, :map_sapling_cost_center, to: :helper_service
  delegate :fetch_user, to: :event_service, prefix: :execute 
  delegate :change_params_mapper_for_custom_field_mapping, to: :integrations_helper_service

  @@old_custom_field_values = []

  def initialize(company, integration)
    @company = company
    @integration = integration
    @sapling_keys = Integration.paylocity
    @parameter_mappings = init_parameter_mappings
  end

  def update
    fetch_updates
  end

  private

  def fetch_updates
    options = get_options
    
    company.users.where.not(paylocity_id: nil).try(:find_each) do |user|
      begin
        params = { user: {}, custom_field: {} }
        @@old_custom_field_values = []
        next unless can_integrate_profile?(integration, user)

        response = execute_fetch_user(integration.company_code, user.paylocity_id, options)
        
        if response.code == 401
          options = get_options
          response = execute_fetch_user(integration.company_code, user.paylocity_id, options)
        end

        if response.code == 200
          @parameter_mappings.each do |key, value|
            get_data(key, value, params, response, user)
          end
          duplicate_user = user.attributes
          update_user_information(user, params, @parameter_mappings)
          default_field_names = params[:user].keys
          
          begin
            WebhookEvents::ManageWebhookPayloadJob.perform_async(company.id, {default_data_change: default_field_names, user: user.id, temp_user: duplicate_user, webhook_custom_field_data: @@old_custom_field_values})
          rescue Exception => e
            puts e.message
          end
          create_loggings(company, "Update user in Sapling (#{user.id}) from Paylocity - Success", 200, {request: "GET Employee/#{user.id}"},  {result: response})
        elsif response.code == 401
          create_loggings(company, "Update user in Sapling (#{user.id}) from Paylocity - Failure", response.code, {request: "GET Employee/#{user.id}"}, {result: response})
          break
        else
          create_loggings(company, "Update user in Sapling (#{user.id}) from Paylocity - Failure", response.code, {request: "GET Employee/#{user.id}"}, {result: response})
        end

      rescue Exception => e
        create_loggings(company, "Update user in Sapling (#{user.id}) from Paylocity - Failure", 500, {request: "GET Employee/#{user.id}"}, {result: e.message})
      end
    end
  end

  def get_options
    configuration.get_basic_options(sapling_keys.client_id, sapling_keys.secret_token)
  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end

  def configuration 
    HrisIntegrationsService::Paylocity::Configuration.new
  end

  def event_service
    HrisIntegrationsService::Paylocity::Eventsv1.new
  end
  
  def integrations_helper_service
    IntegrationCustomMappingHelper.new
  end
  
  def init_parameter_mappings
    params_mapping = ::HrisIntegrationsService::Paylocity::ParamsMapper.new.build_sapling_parameter_mappings
    change_params_mapper_for_custom_field_mapping(params_mapping, @integration, @company, 'pull')
  end

  def get_data(key, meta, params, response, user)
    parent_hash = meta['parent_hash_path'.to_sym]
    value = parent_hash.present? ? fetch_value(parent_hash, response) : response[key.to_s]

    #we cant update the below values from paylocity if company is using custom table.
    return if value.blank? || (company.is_using_custom_table.present? && ['manager id', 'Employment Status', 'Base Rate', 'BaseRate', 'Salary', 'Pay Type', 'Pay Frequency', 'title', 'termination date', 'user state'].include?(meta[:name]))

    field_name = meta[:name].to_s.downcase.tr(' ', '_').to_sym

    case field_name 
    when :user_state
      state = map_sapling_state(value)
      params[:user][:state] = state if state.present?  
    when :termination_date, :start_date
      params[:user][field_name] = value if !user.is_rehired  
    when :gender
      gender = map_sapling_gender(value)
      params[:custom_field][field_name] = gender if gender.present?
    when :federal_marital_status
      marital_status = map_sapling_marital_status(value)
      params[:custom_field][field_name] = marital_status if marital_status.present?
    when :pay_frequency
      pay_frequency = map_sapling_pay_frequency(value)
      params[:custom_field][field_name] = pay_frequency if pay_frequency.present?
    when :employment_status
      status = map_sapling_employee_type(value)
      params[:custom_field][field_name] = status if status.present?
    when :manager_id 
      manager_id = map_sapling_manager(value, user)
      params[:user][field_name] = manager_id if manager_id.present? 
    when :costcenter1, :costcenter2, :costcenter3
      sapling_field_name = fetch_sapling_field_name(field_name.to_s.downcase, value)

      if sapling_field_name.present?
        if meta[:is_custom].blank? && !company.is_using_custom_table
          if key.to_s == 'location'
            params[:user][:location_id] = Location.get_location_by_name(company, sapling_field_name)&.id
          elsif key.to_s == 'department'
            params[:user][:team_id] = Team.get_team_by_name(company, sapling_field_name)&.id
          end
        elsif meta[:is_custom]
          custom_field = CustomField.get_custom_field(company, key.to_s.tr("_", " ").downcase)
          if custom_field&.custom_section_id.present? || custom_field&.section.present?
            option = custom_field&.custom_field_options&.find_by('option ILIKE ?', sapling_field_name)&.option
            if option.present?
              params[:custom_field][key] = option
              meta[:name] = custom_field&.name
            end
          end
        end
      end
    else
      if meta[:is_custom].blank?
        params[:user][field_name] = value
      else 
        params[:custom_field][field_name] = value
      end
    end
  end

  def fetch_value(parent_hash_path, response)
    paths = parent_hash_path.split('|')
    data = response
    paths.each do |path|
      data = data[path.to_s]
    end
    data

  end 

  def update_user_information(user, params, parameter_mappings)
    if params[:user].present?
      user.update!(params[:user])
    end

    parameter_mappings.each do |key, value|
      update_custom_field_data(value, params, user)
    end
  end

  def update_custom_field_data(meta, params, user)
    return unless meta[:is_custom].present?

    field_name = ['Line 1', 'Line 2', 'City', 'State', 'Zip', 'Country'].include?(meta[:name]) ? 'Home Address' : meta[:name]
    old_value = nil
    key = meta[:name].to_s.downcase.tr(' ', '_').to_sym
    value = params[:custom_field][key]
    
    return unless value
    
    case key 
    when :home_phone_number, :mobile_phone_number
      old_value = user.get_custom_field_value_text(meta[:name])
      phone_number = CustomField.parse_phone_string_to_hash(value)
      if phone_number.present?
        CustomFieldValue.set_sub_custom_field_value(user, meta[:name], phone_number[:country_alpha3], 'Country') if phone_number[:country_alpha3]
        CustomFieldValue.set_sub_custom_field_value(user, meta[:name], phone_number[:area_code], 'Area Code') if phone_number[:area_code]
        CustomFieldValue.set_sub_custom_field_value(user, meta[:name], phone_number[:phone], 'Phone') if phone_number[:phone]
      end
    when :line_1, :line_2, :city, :state, :country, :zip
      old_value = user.get_custom_field_value_text('Home Address')
      CustomFieldValue.set_sub_custom_field_value(user, 'Home Address', value, meta[:name])
    when :baserate, :salary, :base_rate
      old_value = user.get_custom_field_value_text(meta[:name])
      custom_field = company.custom_fields.find_by(name: meta[:name])
      CustomFieldValue.set_custom_field_value(user, nil, value, 'Currency Value', false, custom_field, false, false)
    else
      old_value = user.get_custom_field_value_text(meta[:name])
      CustomFieldValue.set_custom_field_value(user, meta[:name], value)
    end
    
    @@old_custom_field_values.push({name: field_name, old_value: old_value}) if !@@old_custom_field_values.map { |m| m[:name] == field_name }.any?
  end

  def fetch_sapling_field_name(field_name, value)
    map_sapling_cost_center(field_name.to_s.downcase, value, integration)
  end
end
