module WebhookServices
  class SalesforceService
    attr_reader :params, :company

    CREATE_LEAD_URL = 'http://mts-sforce1.saplinghr.com/create_lead'

    def initialize(params, company)
      @params = params
      @company = company
    end

    def trigger
      post_to_salesforce_micro_service
    end

    private

    def post_to_salesforce_micro_service
      response = post(CREATE_LEAD_URL, generate_signature(params.to_h))
      log_lead_creation("Lead #{response&.status == 200 ? '' : 'Not '}Created")
    end

    def post(url, signature)
      Faraday.new.post(url) do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-Sapling-Signature'] = signature
        req.body = params.to_json
      end
    end

    def generate_signature(request_body)
      request_body = JSON.generate(request_body)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), ENV['SALESFORCE_REQUEST_TOKEN'], request_body)
    end

    def log_lead_creation(message)
      LoggingService::GeneralLogging.new.create(company, message, params.to_h)
    end

  end
end
