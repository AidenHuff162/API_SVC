class SaplingApiService::WebhookServices::ValidatorService
  attr_reader :company, :params, :action
  
  delegate :filters_not_valid?, :configurable_not_valid?, to: :helper_service
  delegate :filters_format_invalid?, to: :helper_service

  INDEX_FILTERS = [ 'limit', 'page', 'status' ]
  SHOW_FILTERS = [ 'id' ]
  VALID_ATTRIBUTES_FOR_CREATE = [ 'event', 'status', 'url', 'description', 'filters', 'configurable' ]
  REQUIRED_ATTRIBUTES_FOR_CREATE = [ 'event', 'url']
  VALID_ATTRIBUTES_FOR_UPDATE = [ 'status', 'url', 'description', 'filters', 'id', 'configurable' ]
  REQUIRED_ATTRIBUTES_FOR_UPDATE = [ 'id' ]
  
  def initialize(company, params, action)
    @company = company
    @params = params
    @action = action
  end

  def perform
    execute_operation
  end

  private

  def execute_operation
    case action
    when 'index'
      index_validator
    when 'show'
      show_validator
    when 'create'
      create_validator
    when 'update'
      update_validator
    end
  end

  def index_validator
    if params.keys.to_set.subset?(INDEX_FILTERS.to_set).blank? || (params.key?('status').present? && 
      ['active', 'inactive'].exclude?(params[:status].downcase))
      return { message: I18n.t('api_notification.invalid_filters'), status: 400, error: true }
    end
  end

  def show_validator
    if params.keys.to_set.subset?(SHOW_FILTERS.to_set).blank?
      return { message: I18n.t('api_notification.filters_not_allowed'), status: 400, error: true }
    end
  end

  def create_validator
    valid_attributes_validation = validate_valid_attributes_for_create
    return valid_attributes_validation if valid_attributes_validation.present?

    required_attributes_validation = validate_required_attributes_for_create
    return required_attributes_validation if required_attributes_validation.present?

    attributes_value_validation = validate_attribute_values
    return attributes_value_validation if attributes_value_validation.present?    
  end

  def update_validator
    valid_attributes_validation = validate_valid_attributes_for_update
    return valid_attributes_validation if valid_attributes_validation.present?

    required_attributes_validation = validate_required_attributes_for_update
    return required_attributes_validation if required_attributes_validation.present?

    add_event_in_params

    attributes_value_validation = validate_attribute_values
    return attributes_value_validation if attributes_value_validation.present?
  end

  def validate_valid_attributes_for_create
    if params.keys.to_set.subset?(VALID_ATTRIBUTES_FOR_CREATE.to_set).blank?
      return { message: I18n.t('api_notification.invalid_attributes'), status: 400, error: true }
    end
  end

  def validate_required_attributes_for_create
    required_attributes = REQUIRED_ATTRIBUTES_FOR_CREATE
    # required_attributes.push('configurable') if ['stage completed', 'stage started'].include?(params[:event].downcase)

    if required_attributes.all?{ |key| params.key?(key) }.blank?
      return { message: I18n.t('api_notification.required_attributes_are_missing'), status: 400, error: true }
    end
  end

  def validate_valid_attributes_for_update
    if params.keys.to_set.subset?(VALID_ATTRIBUTES_FOR_UPDATE.to_set).blank?
      return { message: I18n.t('api_notification.invalid_attributes'), status: 400, error: true }
    end
  end

  def validate_required_attributes_for_update
    if REQUIRED_ATTRIBUTES_FOR_UPDATE.all?{ |key| params.key?(key) }.blank?
      return { message: I18n.t('api_notification.required_attributes_are_missing'), status: 400, error: true }
    end
  end

  def validate_attribute_values
    status_validation = validate_status
    return status_validation if status_validation.present?

    event_validation = validate_event
    return event_validation if event_validation.present?

    url_validation = validate_url
    return url_validation if validate_url.present?

    event_against_filters_validation = validate_event_against_filters
    return event_against_filters_validation if event_against_filters_validation

    event_against_configurable_validation = validate_event_against_configurable
    return event_against_configurable_validation if event_against_configurable_validation

    filters_validation = validate_filters
    return filters_validation if filters_validation.present?

    configurable_validation = validate_configurable
    return configurable_validation if configurable_validation.present?
  end

  def validate_status
    if params.key?('status') && ['active', 'inactive'].exclude?(params[:status].downcase)
      return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'status'), status: 400, error: true }
    end
  end

  def validate_event
    if params.key?('event') && Webhook.events.keys.map(&:titleize).map(&:downcase).exclude?(params[:event].downcase)
      return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'event'), status: 400, error: true }
    end
  end

  def validate_url
    if params.key?('url') && params[:url].blank?
      return { message: I18n.t('api_notification.required_attributes_are_missing'), status: 400, error: true }
    end
  end

  def validate_event_against_configurable
    begin
      if params.key?('configurable')
        case params[:event].downcase
        when 'new pending hire'
          return { message: I18n.t('api_notification.configurable_not_allowed_for_event', event: params[:event]), status: 400, error: true }
        end
      end
    rescue Exception => e
      case params[:event]
      when 'new pending hire'
        return { message: I18n.t('api_notification.configurable_not_allowed_for_event', event: params[:event]), status: 400, error: true }
      else
        return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'filters'), status: 422, error: true }
      end
    end
  end

  def validate_event_against_filters
    begin
      if params.key?('filters')
        case params[:event].downcase
        when 'new pending hire'
          return { message: I18n.t('api_notification.filters_not_allowed_for_event', event: params[:event]), status: 400, error: true }
        end
      end
    rescue Exception => e
      case params[:event]
      when 'new pending hire'
        return { message: I18n.t('api_notification.filters_not_allowed_for_event', event: params[:event]), status: 400, error: true }
      else
        return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'filters'), status: 422, error: true }
      end
    end
  end

  def validate_filters
    begin
      if filters_format_invalid?(params)
        return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'filters'), status: 422, error: true } 
      end

      if params[:filters].present?
        filters = eval(params[:filters])
        difference = filters.keys - [:locations, :departments, :employmentStatuses]
        if difference.present? || filters_not_valid?(filters, company)
          return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'filters'), status: 422, error: true }
        end
      end
    rescue Exception => e
      return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'filters'), status: 422, error: true } 
    end
  end

  def validate_configurable
    begin
      if params[:configurable].present? && eval(params[:configurable]).class != Array
        return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'configurable'), status: 422, error: true } 
      end

      if params[:configurable].present?
        configurable = eval(params[:configurable])
        if configurable.present?
          configurable = configurable.map(&:titleize).map(&:downcase)
          if configurable_not_valid?(configurable, params[:event], company)
            return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'configurable'), status: 422, error: true }
          end
        end
      end
    rescue Exception => e
      return { message: I18n.t('api_notification.invalid_attribute_value', attribute: 'configurable'), status: 422, error: true } 
    end
  end

  private

  def helper_service
    SaplingApiService::WebhookServices::HelperService.new
  end

  def add_event_in_params
    params.merge!({event: company.webhooks.find_by(guid: params['id']).try(:event).gsub('_', ' ')})
  end
end