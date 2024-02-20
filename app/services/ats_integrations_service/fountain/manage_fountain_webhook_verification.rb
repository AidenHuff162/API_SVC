class AtsIntegrationsService::Fountain::ManageFountainWebhookVerification
  delegate :create, to: :logging_service, prefix: :log
  delegate :authorize_webhook, :fountain_api, :is_verified?, to: :helper_service
  attr_reader :params, :fountain_signature

  def initialize(params, fountain_signature)
    @params = params
    @fountain_signature = fountain_signature
  end

  def verify_and_create
    begin
      status = '404'
      error = nil
      current_company = nil

      client_id = params['applicant']['client_id'] rescue nil
      api_key = params['applicant']['client_api_key'] rescue nil
      return unless client_id.present? || api_key.present? 

      current_company = authorize_webhook(client_id)
      @fountain_api = fountain_api(current_company, client_id, api_key)
      return unless @fountain_api.present?

      if is_verified?(params, fountain_signature)
        ::AtsIntegrationsService::Fountain::ManageFountainProfileInSapling.new(current_company, @fountain_api, params).create_profile
        status = '201'
      end
    rescue Exception => e
      status = '500'
      error = e.message
    ensure
      log_create(current_company, 'Fountain', 'Create', {params: params}.inspect, status, 'FountainController/create', error) if status != '201'
    end
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def helper_service
    AtsIntegrationsService::Fountain::Helper.new
  end
end
