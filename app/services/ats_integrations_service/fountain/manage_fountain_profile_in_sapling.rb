class AtsIntegrationsService::Fountain::ManageFountainProfileInSapling
  delegate :create, to: :logging_service, prefix: :log
  delegate :update_partner, to: :endpoint_service
  delegate :is_pending_hire_exists?, to: :helper_service
  attr_reader :company, :fountain_api, :params, :data_builder, :parameter_mappings

  def initialize(company, fountain_api, params)
    @company = company
    @params = params
    @fountain_api = fountain_api
    @parameter_mappings = init_parameter_mappings
    @data_builder = init_data_builder
  end

  def create_profile
    applicant_id = @params["applicant"]["applicant_id"]
    applicant = @params['applicant']
    if !is_pending_hire_exists?(applicant_id, @company)
      ::AtsIntegrationsService::Fountain::CreateFountainProfileInSapling.new(@company, @fountain_api, applicant, @parameter_mappings, @data_builder).create
    end
  end

  def init_parameter_mappings
    ::AtsIntegrationsService::Fountain::ParamsMapper.new.fountain_params_mapper
  end

  def init_data_builder
    ::AtsIntegrationsService::Fountain::DataBuilder.new(@parameter_mappings)
  end

  def logging_service
    LoggingService::WebhookLogging.new
  end

  def endpoint_service
    ::AtsIntegrationsService::Fountain::Endpoint.new
  end

  def helper_service
    AtsIntegrationsService::Fountain::Helper.new
  end
end
