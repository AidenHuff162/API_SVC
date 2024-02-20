module WebhookEventServices
  class ExecuteEventService
    attr_reader :company, :webhook_event

    delegate :generate_signature, :create_integration_logging, to: :helper_service
    delegate :build_webhook_event_params, to: :params_builder_service

    def initialize(company_id, event_id)
      @company = Company.active_companies.find_by(id: company_id)
      return unless @company.present?
      
      @webhook_event = company.webhook_events.find_by(id: event_id)
      return unless @webhook_event.present?
      
      update_webhook_request_params if webhook_event.request_body['webhook_event'].blank?
    end

    def perform
      dispatch
    end

    private

    def update_webhook_request_params
      request_body = webhook_event.request_body
      request_body["webhook_event"].merge!(build_webhook_event_params(webhook_event)) if request_body["webhook_event"].present?
      webhook_event.update!(request_body: request_body)
    end

    def dispatch
      return unless company.present? && webhook_event.present?
      signature = generate_signature(webhook_event.request_body["webhook_event"], company)
      
      response = post(webhook_event.webhook.target_url, webhook_event.request_body, signature)
      
      params = {
        response_body: prepare_response_body(response),
        status: ([200, 201, 204].include?(response&.status) ? WebhookEvent.statuses[:succeed] : WebhookEvent.statuses[:failed]),
        triggered_at: DateTime.now,
        response_status: response&.status
      }
      
      webhook_event.update_columns(params)
    end

    def prepare_response_body(response)
      {
        status: response&.status,
        headers: response&.headers&.to_h,
        body: (JSON.parse(response.body) rescue {})
      }
    end
    
    def post(url, request_body, signature)
      begin
        Faraday.new.post(url) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.headers['X-Sapling-Signature'] = signature
          req.body = request_body.to_json
        end
      rescue Exception => e
        create_integration_logging(request_body, e.message, 500, company)
      end
    end

    def helper_service
      SaplingApiService::WebhookServices::HelperService.new
    end

    def params_builder_service
      WebhookEventServices::ParamsBuilderService.new
    end
  end
end