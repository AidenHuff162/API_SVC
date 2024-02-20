class LearningAndDevelopmentIntegrationServices::Kallidus::CreateSaplingProfileInKallidus
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
      
      if response.created?
        user.update_column(:created_at_kallidus, DateTime.now)
        loggings('Success', response.code, response.body, request_data, request_params)
      else
        loggings('Failure', response.code, response.body, request_data, request_params)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, request_data, request_params)
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Endpoint.new
  end

  def loggings status, code, parsed_response, request_data, request_params
    create_loggings(@company, 'KallidusLearn', code, "Create user in Kallidus - #{status}", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end
