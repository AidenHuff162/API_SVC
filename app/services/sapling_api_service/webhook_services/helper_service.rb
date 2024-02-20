class SaplingApiService::WebhookServices::HelperService

  def log(company, token, request, data, status, message, location)
    create_sapling_api_logging(company, token, request, data, status.to_s, message, location)
    log_integration_statistics(status, company)
  end

  def format_read_filters(company, filter_name, filter_value)
    if filter_value.include?('all')
      ["All #{filter_name.titleize}"]
    else
      case filter_name
      when 'locations'
        locations = company.locations.where(id: filter_value).pluck(:name)
        locations.present? ? locations : ['Not Selected']
      when 'departments'
        departments = company.teams.where(id: filter_value).pluck(:name)
        departments.present? ? departments : ['Not Selected']
      when 'employment statuses'
        employment_statuses = company.custom_fields.where('name ILIKE ?', 'employment status').take&.custom_field_options&.where(option: filter_value)&.pluck(:option)
        employment_statuses.present? ? employment_statuses : ['Not Selected']
      end
    end
  end
  
  def prepare_webhook_data(webhook, company)
    data = { 
      webhookId: webhook.guid,
      event: webhook.event.titleize,
      url: webhook.target_url,
      description: webhook.description,
      status: webhook.state,
      createdAt: webhook.created_at,
      createdBy: webhook.created_by_reference,
      updatedAt: webhook.updated_at,
      updatedBy: webhook.updated_by_reference
    }.merge!(prepare_last_webhook_event_data(webhook))
    
    if webhook.new_pending_hire?.blank?
      data[:configurable] = prepare_configurable_data(webhook, company)
      data[:appliesTo] = prepare_applies_to_data(webhook, company)
    end

    data
  end
  
  def prepare_filters(filters, company)
    locations = filters[:locations].present? ? get_location_ids(filters[:locations], company) : []
    departments = filters[:departments].present? ? get_department_ids(filters[:departments], company) : []
    employment_statuses = filters[:employmentStatuses].present? ? get_statuses(filters[:employmentStatuses], company) : []

    { location_id: locations, team_id: departments, employee_type: employment_statuses }
  end

  def prepare_configurables(event, configurable, company)
    return {} if ['new pending hire'].include?(event.downcase)
    key = ''
    case event.downcase
    when 'stage started', 'stage completed'
      key = 'stages'
    when 'key date reached'
      key =  'date_types'
    when 'profile changed', 'job details changed'
      key = 'fields'
    end

    { "#{key}": set_configurable(configurable.map(&:titleize).map(&:downcase), key, company) }
  end
  
  def filters_not_valid?(filters, company)
    check_filters(filters[:locations], company, 'locations') || check_filters(filters[:departments], company, 'departments') || check_filters(filters[:employmentStatuses], company, 'employment statuses')
  end

  def filters_format_invalid?(params)
    params.key?('filters') && eval(params[:filters]).present? && eval(params[:filters]).class != Hash
  end
  
  def configurable_not_valid?(configurable, event, company)
    case event.downcase
    when 'stage started', 'stage completed'
      configurable.to_set.subset?(User.current_stages.keys.to_set.map(&:titleize).map(&:downcase).to_set).blank?
    when 'key date reached'
      configurable.to_set.subset?(Webhook::DATE_TYPES.to_set).blank?
    when 'profile changed'
      configurable.to_set.subset?(get_profile_fields(company).to_set).blank?
    when 'job details changed'
      configurable.to_set.subset?(get_job_details_fields(company).to_set).blank?
    end
  end

  def generate_signature(request_body, company)
    client_secret = company.webhook_token
    request_body = JSON.generate(request_body)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), client_secret, request_body)
  end

  def create_integration_logging(request, response, status, company)
    integration_logging ||= LoggingService::IntegrationLogging.new
    integration_logging.create(company, 'Webhooks', 'post webhook payload', request, response, status)
  end

  private

  def prepare_configurable_data(webhook, company)
    if webhook.new_pending_hire?.blank?
      configurable = webhook.extract_configurable
      if configurable.present?
        return get_configurable(webhook.event, configurable, company)
      end
    end
    []
  end

  def prepare_applies_to_data(webhook, company)
    filters = webhook.filters

    {
      locations: (filters.present? && filters['location_id'].present? ? format_read_filters(company, 'locations', filters['location_id']) : ['Not Selected']),
      departments: (filters.present? && filters['team_id'].present? ? format_read_filters(company, 'departments', filters['team_id']) : ['Not Selected']),
      employmentStatuses: (filters.present? && filters['employee_type'].present? ? format_read_filters(company, 'employment statuses', filters['employee_type']) : ['Not Selected'])
    }
  end

  def create_sapling_api_logging(company, token, request, data, status, message, location)
    @sapling_api_logging ||= ::LoggingService::SaplingApiLogging.new
    @sapling_api_logging.create(company, token, request.url, data.to_json, status, message, location)
  end

  def log_integration_statistics(status, company)
    @integration_statistics ||= ::RoiManagementServices::IntegrationStatisticsManagement.new
    
    if [ 200, 201 ].include?(status) 
      @integration_statistics.log_success_api_calls_statistics(company)
    else
      @integration_statistics.log_failed_api_calls_statistics(company)
    end
  end

  def prepare_last_webhook_event_data(webhook)
    webhook_event = webhook.webhook_events.with_descending_order.take
    
    {
      triggeredBy: (webhook_event&.triggered_by_source || ['Not Available']),
      lastTriggered: (webhook_event&.triggered_at || 'Not Available'),
      lastTriggeredEventStatus: (webhook_event&.status || 'Not Available')
    }
  end


  def get_location_ids(location_filters, company)
    return ['all'] if location_filters == ['all locations']
    
    location_filters.map {|loc| company.locations.where('name ILIKE ?', loc).take.try(:id)}.compact
  end

  def get_department_ids(department_filters, company)
    return ['all'] if department_filters == ['all departments']
    
    department_filters.map {|dep| company.teams.where('name ILIKE ?', dep).take.try(:id)}.compact
  end

  def get_statuses(statuses_filters, company)
    return ['all'] if statuses_filters == ['all employment statuses']
    employment_status_field = company.custom_fields.where(field_type: :employment_status).take

    statuses_filters.map {|status| employment_status_field.custom_field_options.where('option ILIKE ?', status).take.try(:option)}
  end


  def check_filters(filters, company, type)
    case type
    when 'locations'
      return filters.present? && ((filters.map!(&:downcase).count > 1 && (filters.include?('all locations')) || 
          (filters.exclude?('all locations') && filters.to_set.subset?(company.locations.pluck(:name).map(&:downcase).to_set).blank?)))
    when 'departments'
      return filters.present? && ((filters.map!(&:downcase).count > 1 && (filters.include?('all departments')) || 
          (filters.exclude?('all departments') && filters.to_set.subset?(company.teams.pluck(:name).map(&:downcase).to_set).blank?)))
    when 'employment statuses'
      return filters.present? && ((filters.map!(&:downcase).count > 1 && filters.include?('all employment statuses')) || 
          (filters.exclude?('all employment statuses') && 
          filters.to_set.subset?(company.custom_fields.where(field_type: :employment_status).take.custom_field_options.pluck(:option).map(&:downcase).to_set).blank?))
    end
  end

  def get_profile_fields(company)
    (company.prefrences['default_fields'].map { |field| field['name'].downcase if Webhook::PROFILE_SECTIONS.include?(field['section'])}.compact + company.custom_fields.where(section: Webhook::PROFILE_SECTIONS).pluck(:name).map(&:downcase) - excluded_fields)
  end

  def get_job_details_fields(company)
    ((company.prefrences['default_fields'].map { |field| field['name'].downcase if Webhook::PROFILE_SECTIONS.exclude?(field['section'])}.compact + company.custom_fields.where(section: nil).pluck(:name).map(&:downcase) - excluded_fields).uniq - excluded_fields)
  end

  def excluded_fields
    Webhook::EXCLUDED_FIELDS
  end

  def set_configurable(configurable, key, company)
    case key
    when 'stages', 'date_types'
      configurable.map(&:downcase).map(&:parameterize).map(&:underscore)
    when 'fields'
      company.prefrences['default_fields'].map { |field| field['api_field_id'] if configurable.include?(field['name'].downcase)}.compact + company.custom_fields.where('lower(name) IN (?)',configurable).pluck(:api_field_id)
    end
  end

  def get_configurable(event, configurable, company)
    case event
    when 'stage_started', 'stage_completed', 'key_date_reached'
      configurable.map(&:titleize)
    when 'profile_changed', 'job_details_changed'
      company.prefrences['default_fields'].map { |field| field['name'] if configurable.include?(field['api_field_id'])}.compact + company.custom_fields.where(api_field_id: configurable).pluck(:name)
    end
  end
end