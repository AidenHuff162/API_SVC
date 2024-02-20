class SaplingApiService::WebhookServices::ManageWebhookService
  attr_reader :company, :request, :token, :params, :action

  delegate :log, to: :helper_service, prefix: :create
  delegate :perform, to: :validator_service, prefix: :execute_webhook_validator
  delegate :perform, to: :reader_service, prefix: :execute_webhook_reader
  delegate :perform, to: :writer_service, prefix: :execute_webhook_writer
  delegate :perform, to: :destroyer_service, prefix: :execute_webhook_destroyer
  
  def initialize(company, request, token, params, action)
    @company = company
    @request = request
    @token = token
    @params = filterate_params(params)
    @action = action
  end

  def perform
    validation = execute_webhook_validator_perform
    
    if validation.present?
      create_log(company, token, request, params, validation[:status], validation[:message], 'SaplingApiService::WebhookServices::ManageWebhookService')
      return validation 
    end

    result = execute_operation
    create_log(company, token, request, params, result[:status], result[:message], 'SaplingApiService::WebhookServices::ManageWebhookService')
    return result
  end

  private

  def filterate_params(params)
    params.delete(:format)
    params.delete(:controller)
    params.delete(:action)

    params
  end

  def execute_operation
    case action
    when 'index', 'show'
      execute_webhook_reader_perform
    when 'create', 'update'
      execute_webhook_writer_perform
    when 'destroy'
      execute_webhook_destroyer_perform
    end
  end

  def helper_service
    SaplingApiService::WebhookServices::HelperService.new
  end

  def validator_service
    SaplingApiService::WebhookServices::ValidatorService.new(company, params, action)
  end

  def reader_service
    SaplingApiService::WebhookServices::ReaderService.new(company, params, action)
  end

  def writer_service
    SaplingApiService::WebhookServices::WriterService.new(company, params, action)
  end

  def destroyer_service
    SaplingApiService::WebhookServices::DestroyerService.new(company, params, action)
  end
end
