class HrisIntegrationsService::Trinet::CreateSaplingProfileInTrinet
	attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, :log_statistics, to: :helper_service
  delegate :create, to: :endpoint_service, prefix: :execute 
	
	def initialize ( company, user, integration, data_builder, params_builder)
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
		begin
  		request_data = @data_builder.build_create_profile_data(@user)
  		request_params = @params_builder.build_create_profile_params(request_data)

  		return unless request_params.present?
      response = execute_create(@integration, request_params)
      parsed_response = JSON.parse(response.body)
      if response.code.to_s == '200'
        create_loggings(@company, @integration, 'Trinet', response.code, "Create user in Trinet - Success", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('success', @company)
      else
        create_loggings(@company, @integration, 'Trinet', response.code, "Create user in Trinet - Failure", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('failed', @company)
      end
    rescue Exception => e
      create_loggings(@company, @integration, 'Trinet', 500, "Create user in Trinet - Failure", {response: e}, {data: request_data, params: request_params}.inspect)
      log_statistics('failed', @company)
    end
	end

	def helper_service
    HrisIntegrationsService::Trinet::Helper.new
  end

	def endpoint_service
    HrisIntegrationsService::Trinet::Endpoint.new
  end
end