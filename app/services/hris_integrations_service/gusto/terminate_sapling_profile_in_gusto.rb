class HrisIntegrationsService::Gusto::TerminateSaplingProfileInGusto
  attr_reader :company, :user, :integration

  delegate :create_loggings, :log_statistics, to: :helper_service
  delegate :terminate_user, to: :endpoint_service

  def initialize(company, user, integration, data_builder, params_builder)
    @company = company
    @user = user.reload
    @integration = integration

    @data_builder = data_builder
    @params_builder = params_builder
  end

  def perform
    request_data = @data_builder.build_create_profile_data(@user)
    request_params = @params_builder.build_create_profile_params(request_data)
    return unless request_params.present?
    
    begin
      response = terminate_user(@integration, @user.gusto_id, request_params["terminate"])
      parsed_response = JSON.parse(response.read_body)

      if response.code == '201'  
        loggings('Success', response.code, parsed_response, request_data, request_params["terminate"])
      else
        loggings('Failure', response.code, parsed_response, request_data, request_params["terminate"])
        
      end
    rescue Exception => e
      loggings('Failure', 500, e.message, request_data, request_params["terminate"])
    end
  end

  private

  def helper_service
    HrisIntegrationsService::Gusto::Helper.new
  end

  def endpoint_service
    HrisIntegrationsService::Gusto::Endpoint.new
  end

  def loggings status, code, response, request_data, request_params
    create_loggings(@company, 'Gusto', code, "Terminate user in gusto - #{status}", {response: response}, {data: request_data, params: request_params}.inspect)
    log_statistics(status.downcase, @company)
  end
end