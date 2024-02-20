class AtsIntegrationsService::Fountain::CreateFountainProfileInSapling
  delegate :create, to: :logging_service, prefix: :log
  delegate :update_partner_status, to: :helper_service
  attr_reader :company, :fountain_api, :params, :data_builder, :parameter_mappings

  def initialize(company, fountain_api, params, parameter_mappings, data_builder)
    @company = company
    @params = params
    @fountain_api = fountain_api
    @parameter_mappings = parameter_mappings
    @data_builder = data_builder
  end

  def create
    begin
      data = data_builder.build_create_profile_data(params)
      PendingHire.create_by_fountain(data, @company)
      log_create(@company, 'Fountain', 'Create Fountain Profile in Sapling - Success', {params: params, data: data}.inspect, 201, 'Create')
      update_partner_status(params['applicant_id'], @company)
    rescue Exception => exception
      log_create(@company, 'Fountain', 'Create Fountain Profile in Sapling - Failure', {params: params, data: data}.inspect, 500, 'Create', exception.message)
      update_partner_status(params['applicant_id'], @company, 'error')
    end
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def helper_service
    AtsIntegrationsService::Fountain::Helper.new
  end
end
