class PerformanceManagementIntegrationsService::Lattice::UpdateSaplingProfileInLattice
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
    update
  end

  private
  
  def update
    update_by_scim
  end

  def update_by_scim
    request_data = @data_builder.build_update_profile_data(@user, 'scim')
    request_params = @params_builder.build_update_profile_params(request_data)
    begin
      response = Faraday.new.put("https://api.latticehq.com/scim/v2/Users/#{user.lattice_id}") do |req|
        req.headers['Content-Type'] = 'application/scim+json'
        req.headers['Accept'] = 'application/scim+json'
        req.headers['Authorization'] = "Bearer #{integration.api_key}"
        req.body = request_params.to_json
      end

      if response&.status == 200
        create_loggings(@company, 'Lattice', response.status, "Update user in Lattice (SCIM) - Success", {response: response.body}, {data: request_data, params: request_params})
        log_statistics('success', @company, integration)
      else
        create_loggings(@company, 'Lattice', response.status, "Update user in Lattice (SCIM) - Failure", {response: response.body}, {data: request_data, params: request_params})
        log_statistics('failed', @company, integration)
      end
    rescue Exception => e
      create_loggings(@company, 'Lattice', 500, "Update user in Lattice - Failure", {response: e.message}, {data: request_data, params: request_params})
      log_statistics('failed', @company, integration)
    end
  end
  
  def helper_service
    PerformanceManagementIntegrationsService::Lattice::Helper.new
  end
end