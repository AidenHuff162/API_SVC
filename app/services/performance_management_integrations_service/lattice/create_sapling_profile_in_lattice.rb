class PerformanceManagementIntegrationsService::Lattice::CreateSaplingProfileInLattice
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :log_statistics, to: :helper_service

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
      response = HTTParty.post("https://api.latticehq.com/scim/v2/Users",
        body: request_params,
        headers: { accept: 'application/scim+json', content_type: 'application/scim+json', authorization: "Bearer #{integration.api_key}" }
      )

      parsed_response = JSON.parse(response.body)

      if response.created?
        user.update_column(:lattice_id, parsed_response['id'])
        create_loggings(@company, 'Lattice', response.code, "Create user in Lattice - Success", {response: parsed_response}, {data: request_data, params: request_params})
        log_statistics('success', @company, integration)
      else
        create_loggings(@company, 'Lattice', response.code, "Create user in Lattice - Failure", {response: parsed_response}, {data: request_data, params: request_params})
        log_statistics('failed', @company, integration)
      end
    rescue Exception => e
      create_loggings(@company, 'Lattice', 500, "Create user in Lattice - Failure", {response: e.message}, {data: request_data, params: request_params})
      log_statistics('failed', @company, integration)
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::Lattice::Helper.new
  end
end