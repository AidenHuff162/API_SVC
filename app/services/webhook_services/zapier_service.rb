module WebhookServices
  class ZapierService
    attr_reader :params,:current_company

    def initialize(params, current_company)
      @params = params
      @subdomain = params[:company_domain].split('.')[0] if params[:company_domain].present?
      @current_company = current_company
      @company = Company.find_by(subdomain: @subdomain) if @subdomain.present?
    end

    def subscribe
      current_company_id = @current_company.id if @current_company
      return {code: 404} if current_company_id != @company&.id

      hook = @company.webhooks.find_by(webhook_key: params[:key]) if @company.present? and params[:key].present?
      if hook.present?
        hook.update(target_url: params[:target_url], state: Webhook.states[:active]) 
        return {code: 204}
      else
        return {code: 404}
      end
    end

    def unsubscribe
      hook = @company.webhooks.find_by(webhook_key: params[:key]) if @company.present? and params[:key].present?
      if hook.present?
        hook.update(state: Webhook.states[:inactive]) 
        return {code: 204}
      else
        return {code: 404}
      end
    end

    def authenticate
      hook = @company.webhooks.find_by(webhook_key: params[:key]) if @company.present? and params[:key].present?
      hook.present? and @current_company ? @current_company.id == @company&.id : false
    end

    def perform_list_zap
      data = {}
      hook = @company.webhooks.find_by(webhook_key: params[:key]) if @company.present? and params[:key].present?
      data = WebhookEventServices::TestParamsBuilderService.new.prepare_test_event_params(@company, {type: 'test_event', action: 'test'}, hook) if hook.present?
      data
    end

  end
end