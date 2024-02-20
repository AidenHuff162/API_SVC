class LearningAndDevelopmentIntegrationServices::LearnUpon::CreateSaplingProfileInLearnUpon
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
      
      if response.ok?
        user.update_column(:learn_upon_id, parsed_response['id'])
        UserMailer.notify_user_about_learn_upon_account_creation(user.id, company, integration, request_data[:password]).deliver_now!
        loggings('Success', response.code, parsed_response, request_data, request_params)
      else
        loggings('Failure', response.code, parsed_response, request_data, request_params)
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, request_data, request_params)
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::LearnUpon::Helper.new
  end

  def endpoint_service
    LearningAndDevelopmentIntegrationServices::LearnUpon::Endpoint.new
  end

  def loggings status, code, parsed_response, request_data, request_params
    create_loggings(@company, 'LearnUpon', code, "Create user in learn upon - #{status}", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end