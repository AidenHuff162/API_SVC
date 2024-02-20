class LearningAndDevelopmentIntegrationServices::Kallidus::UpdateSaplingProfileInKallidus
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :update, to: :endpoint_service, prefix: :execute

  def initialize(company, user, integration, data_builder, params_builder, attributes)
    @company = company
    @user = user
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
    @attributes = attributes
  end

  def perform
    update
  end

  private
  
  def update
    request_data = @data_builder.build_update_profile_data(@user, @attributes)
    request_params = @params_builder.build_update_profile_params(request_data)

    return unless request_params.present?

    begin
      response = execute_update(@integration, request_params, user.kallidus_learn_id)
      parsed_response = JSON.parse(response.body) rescue nil
      
      if response.ok?
        loggings('Success', response.code, parsed_response, request_data, request_params)
      else
        loggings('Failure', response.code, parsed_response, request_data, request_params)
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
    create_loggings(@company, 'KallidusLearn', code, "Update user in Kallidus - #{status}", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end