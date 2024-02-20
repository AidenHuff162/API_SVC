class LearningAndDevelopmentIntegrationServices::Lessonly::CreateSaplingProfileInLessonly
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :create, to: :endpoint_service, prefix: :execute 

  def initialize(company, user, integration, data_builder, params_builder)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
  end

  def perform
    create
  end

  private
  
  def create
    request_data = @data_builder.build_create_profile_data(@user)
    request_params = @params_builder.build_create_profile_params(request_data)

    return unless request_params.present?

    begin
      response = execute_create(@integration, request_params)
      parsed_response = JSON.parse(response.body)
      
      if response.created?
        user.update_column(:lessonly_id, parsed_response['id'])
        loggings('Success', response.code, parsed_response, request_data, request_params)
      else
        loggings('Failure', response.code, parsed_response, request_data, request_params)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, request_data, request_params)
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::Lessonly::Endpoint.new
  end

  def loggings status, code, parsed_response, request_data, request_params
    create_loggings(@company, 'Lessonly', code, "Create user in lessonly - #{status}", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end