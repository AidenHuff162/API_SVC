module WebhookEventServices
  class ExecuteTestEventService
    attr_reader :company

    delegate :generate_signature, to: :helper_service

    def initialize(webhook_params, current_company)
      @company = current_company
      @webhook = webhook_params
      return unless @webhook.present?
    end

    def perform
      dispatch
    end

    private

    def dispatch
      return unless @webhook.present? && company.webhook_token.present?
      data = {data: "testing webhook endpoint while creation", test_request: true }
      signature = generate_signature(data, company)

      begin
        response = post(@webhook[:target_url], data, signature)
        status = ([200, 201, 204].include?(response.status) ? "Success" : "Failed")
        body = {
          status: response.status,
          headers: response.headers.to_h,
          body: (JSON.parse(response.body) rescue {})
        }

        created_at = Webhook.get_formatted_date_time(DateTime.now.to_s, company, false)
        date_time = created_at[:date] + ' ' + created_at[:time]
        
        {created_at: date_time, event_id: @webhook[:event_id], status: status, response_body: JSON.pretty_generate(body)}
      rescue Exception => e
        {error: e.message}
      end
    end

    def post(url, request_body, signature)
      Faraday.new.post(url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Sapling-Signature'] = signature
        req.body = request_body.to_json
      end
    end

    def helper_service
      SaplingApiService::WebhookServices::HelperService.new
    end
  end
end