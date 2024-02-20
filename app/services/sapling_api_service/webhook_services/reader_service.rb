class SaplingApiService::WebhookServices::ReaderService
  attr_reader :company, :params, :action

  delegate :format_read_filters, to: :helper_service
  delegate :prepare_webhook_data, to: :helper_service

  def initialize(company, params, action)
    @company = company
    @params = params
    @action = action
  end

  def perform
    
    case action
    when 'index'
      fetch_webhooks
    when 'show'
      fetch_webhook
    end
  end

  private

  def filterate_webhooks(webhooks)
    if params[:status].present? && ['active', 'inactive'].include?(params[:status].downcase)
      webhooks = webhooks.where(state: params[:status].downcase) 
    end

    return webhooks
  end

  def fetch_webhooks
    webhooks = filterate_webhooks(company.webhooks)

    if params[:limit].present?
      if params[:limit].to_i <= 0
        return { message: I18n.t('api_notification.invalid_limit'), status: 400, error: true }
      else
        limit = params[:limit].to_i
      end
    else
      limit = 50
    end

    total_pages = (webhooks.count/limit.to_f).ceil

    if params[:page].present? && (params[:page].to_i <= 0 || total_pages < params[:page].to_i)
      return { message: I18n.t('api_notification.invalid_page_offset'), status: 400, error: true }
    end

    page = (webhooks.count <= 0) ? 0 : (!params[:page].present? || params[:page].to_i == 0 ? 1 : params[:page].to_i)
    data = { current_page: page, total_pages: (webhooks.count <= 0) ? 0 : ((total_pages == 0) ? 1 : total_pages), total_webhooks: webhooks.count, webhooks: [] }

    if page > 0
      paginated_webhooks = webhooks.paginate(:page => page, :per_page => limit)
      paginated_webhooks.each do |webhooks|
        data[:webhooks].push prepare_webhook_data(webhooks, company)
      end
    end

    data.merge!(status: 200, message: I18n.t('api_notification.success'))
  end

  def fetch_webhook
    webhook = company.webhooks.where(guid: params[:id]).take
      
    if webhook.present?
      return { webhook: prepare_webhook_data(webhook, company), status: 200, message: I18n.t('api_notification.success') }
    else
      return { message: I18n.t('api_notification.invalid_webhook_id'), status: 400, error: true }
    end
  end

  def helper_service
    SaplingApiService::WebhookServices::HelperService.new
  end
end