class HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex
	attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, :fetch_integration, :is_integration_valid?, :saved_integration_credentials, :can_integrate_profile?, to: :helper_service

	def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company)
    parameter_mappings = init_parameter_mappings
  end

	def perform(action, attributes = nil)
    @integration.in_progress!

    unless action.present?
      create_loggings(@company, 'Paychex', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'Paychex', 404, "Paychex filters are not for user(#{@user.id}) - #{action}")
      return
    end

    if @integration.access_token.blank? || (Time.now.utc + 10.minutes >= @integration.expires_in&.to_time&.utc)
      status = manage_access_token(action)
      return if status == 'failed'
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Paychex', 404, "Paychex credentials missing - #{action}")
      return
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings
    ::HrisIntegrationsService::Paychex::ParamsMapper.new.build_parameter_mappings
  end
 
  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Paychex::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Paychex::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def manage_access_token(action)
    begin
      response = HrisIntegrationsService::Paychex::Endpoint.new.generate_access_token(@integration)
      
      if response.code != '200'
        create_loggings(@company, 'Paychex', response.code, "Paychex access token generation failed - #{action}")
        return 'failed'
      else 
        saved_integration_credentials(response, @integration)
      end

      @integration.reload
      return 'success'
    rescue Exception => e
      create_loggings(@company, 'Paychex', 500, "Paychex access token generation failed - #{action}", e.message)
      return 'failed'
    end
  end

  def create_profile
    return unless @user.reload.paychex_id.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Paychex::CreateSaplingProfileInPaychex
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.reload.paychex_id.present? && attributes.present?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Paychex::UpdateSaplingProfileInPaychex
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes)
    end
  end

  def helper_service
    HrisIntegrationsService::Paychex::Helper.new
  end
end	
