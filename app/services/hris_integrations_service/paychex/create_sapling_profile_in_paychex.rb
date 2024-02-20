class HrisIntegrationsService::Paychex::CreateSaplingProfileInPaychex
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
		request_data = @data_builder.build_create_profile_data(@user)
		request_params = @params_builder.build_create_profile_params(request_data)
		return unless request_params.present?
		
    begin
      response = execute_create(@integration, request_params)
      parsed_response = JSON.parse(response.read_body)

      if response.code == '201'
        user.update_column(:paychex_id, parsed_response['content'][0]['workerId'])
        
        create_loggings(@company, 'Paychex', response.code, "Create user in paychex - Success", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('success', @company)
      else
        create_loggings(@company, 'Paychex', response.code, "Create user in paychex - Failure", {response: parsed_response}, {data: request_data, params: request_params}.inspect)
        log_statistics('failed', @company)
      end
    rescue Exception => e
      create_loggings(@company, 'Paychex', 500, "Create user in paychex - Failure", {response: e.message}, {data: request_data, params: request_params}.inspect)
      log_statistics('failed', @company)
    end
	end

	def helper_service
    HrisIntegrationsService::Paychex::Helper.new
  end

	def endpoint_service
    HrisIntegrationsService::Paychex::Endpoint.new
  end
end