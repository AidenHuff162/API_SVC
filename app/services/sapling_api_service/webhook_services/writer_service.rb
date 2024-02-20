class SaplingApiService::WebhookServices::WriterService
  attr_reader :company, :params, :action

  delegate :prepare_webhook_data, :prepare_filters, :prepare_configurables, to: :helper_service

  def initialize(company, params, action)
    @company = company
    @params = params
    @action = action
  end

  def perform
    case action
    when 'create'
      create_webhook
    when 'update'
      update_webhook
    end
  end

  private
  
  def create_webhook
    webhook = company.webhooks.build(create_params)
    
    if webhook.save
      { status: 201, message: I18n.t('api_notification.created'), webhook: prepare_webhook_data(webhook, company) }
    else
      { status: 500, message: I18n.t('api_notification.something_went_wrong'), error: true }
    end
  end

  def update_webhook
    webhook = company.webhooks.find_by(guid: params[:id])
    
    if webhook.present?
      if webhook.update(update_params)
        { status: 200, message: I18n.t('api_notification.updated'), webhook: prepare_webhook_data(webhook, company) }
      else
        { status: 500, message: I18n.t('api_notification.something_went_wrong'), error: true }
      end
    else
      { status: 404, message: I18n.t('api_notification.invalid_webhook_id'), error: true }
    end
  end

  def create_params
    attributes = {
      event: params[:event].downcase.parameterize.underscore,
      target_url: params[:url],
      description: params[:description],
      created_from: Webhook.created_froms[:api_call],
      filters: { location_id: [], team_id: [], employee_type: [] },
      configurable: {}
    }
    attributes[:state] = params[:status].downcase if params.key?('status')
    
    if params.key?('filters') && params[:filters].present?
      attributes[:filters] = prepare_filters(eval(params[:filters]), company)
    end

    if params.key?('configurable') && params[:configurable].present?
      attributes[:configurable] = prepare_configurables(params[:event], eval(params[:configurable]), company)
    end

    attributes
  end

  def update_params
    attributes = {
      updated_by_reference: "Sapling API Endpoint", 
      updated_by_id: nil
    }

    attributes[:target_url] = params[:url] if params.key?('url')
    attributes[:state] = params[:status].downcase if params.key?('status')
    attributes[:description] = params[:description] if params.key?('description')
    attributes[:filters] = (params[:filters].present? ? prepare_filters(eval(params[:filters]), company) : { location_id: [], team_id: [], employee_type: [] }) if params.key?('filters')
    attributes[:configurable] = (params[:configurable].present? ? prepare_configurables(params[:event], eval(params[:configurable]), company) : {}) if params.key?('configurable')
    
    attributes
  end

  def helper_service
    SaplingApiService::WebhookServices::HelperService.new
  end
end