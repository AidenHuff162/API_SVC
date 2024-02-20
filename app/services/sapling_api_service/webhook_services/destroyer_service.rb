class SaplingApiService::WebhookServices::DestroyerService
  attr_reader :company, :params, :action

  delegate :prepare_webhook_data, to: :helper_service

  def initialize(company, params, action)
    @company = company
    @params = params
    @action = action
  end

  def perform
    case action
    when 'destroy'
      destroy_webhook
    end
  end

  private

  def destroy_webhook
    webhook = company.webhooks.find_by(guid: params[:id])
    
    if webhook.present?
      if webhook.destroy
        { status: 200, message: I18n.t('api_notification.success') }
      else
        { status: 500, message: I18n.t('api_notification.something_went_wrong'), error: true }
      end
    else
      { status: 404, message: I18n.t('api_notification.invalid_webhook_id'), error: true }
    end
  end

  def helper_service
    SaplingApiService::WebhookServices::HelperService.new
  end
end