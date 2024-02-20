class HrisIntegrationsService::Namely::ManageSaplingProfileInNamely
  attr_reader :company, :user, :integration, :namely, :groups, :parameter_mappings, :data_builder, :params_builder
  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :is_user_exists?,
   :establish_connection, :get_namely_profiles, :get_namely_groups, :log_it, :is_namely_credentials?,
   :log_it, :update_namely_profile, to: :helper_service

  def initialize(company, user)
    @company = company
    @user = user
    @integration = fetch_integration(@company, @user)
    @namely = establish_connection(@integration)
    @groups = get_namely_groups(@integration)
    @parameter_mappings = init_parameter_mappings
    @data_builder = init_data_builder(@parameter_mappings)
    @params_builder = init_params_builder(@parameter_mappings)
  end

  def perform(action, attributes = nil)
    @integration.in_progress!
    unless is_integration_valid?(@integration)
      @integration.failed!
      create_loggings(@company, "Namely credentials missing - Create in Namely", 404, 'No Request', {message: 'Credentials Missing', effected_profile: "#{user.full_name} (#{user.id})"})
      return
    end
    execute(action, attributes)
    @integration.succeed!
    @integration.update_column(:synced_at, DateTime.now)
  end
  
  private

  def create_profile
    HrisIntegrationsService::Namely::CreateSaplingProfileInNamely.new(@user, @namely, @integration, @groups, @data_builder, @params_builder).create
  end

  def update_profile(attributes) 
    HrisIntegrationsService::Namely::UpdateSaplingProfileInNamely.new(@user, @namely, @integration, @groups, @data_builder, @params_builder, attributes).update
  end

  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Namely::DataBuilder.new(parameter_mappings, @company, @integration, @user, @namely)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Namely::ParamsBuilder.new(parameter_mappings)
  end

  def init_parameter_mappings
    params_mapping = ::HrisIntegrationsService::Namely::ParamsMapper.new.push_users_parameters
  end

  def execute(action, attributes)
    if action == 'create'
      create_profile
    elsif action == 'update'
      update_profile(attributes)
    elsif action == 'terminate'
      terminate_profile
    end
  end

  def helper_service
    HrisIntegrationsService::Namely::Helper.new
  end

  def terminate_profile
    begin
      @user.reload
      if is_namely_credentials?(@integration) && @user.namely_id.present? && @user.termination_date.present?
        data = { profiles: [{
          user_status: 'inactive',
          departure_date: @user.termination_date.strftime("%Y-%m-%d")
        }]}
        response = update_namely_profile(data, @integration, @user)
        if response.ok?
          log_it("Terminate User Profile(#{@user.namely_id}) in Namely - Success", {request: data.inspect}, {result: JSON.parse(response.body)}, 204, @company)
        else
          log_it("Terminate User Profile(#{@user.namely_id}) in Namely - Failure", {request: data.inspect}, {result: JSON.parse(response.body)}, response.code, @company)
        end
      end
    rescue Exception => e
      log_it("Terminate User Profile(#{@user.namely_id}) in Namely - Failure", {request: data.inspect}, {result: e.message}, 500, @company)
    end
  end
end
