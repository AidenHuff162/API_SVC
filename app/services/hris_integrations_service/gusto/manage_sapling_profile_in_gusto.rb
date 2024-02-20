class HrisIntegrationsService::Gusto::ManageSaplingProfileInGusto
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :can_integrate_profile?, to: :helper_service

  def initialize(user)
    @user = user.reload
    @company = user.company
    @integration = fetch_integration(@company, @user)
  end

  def perform(action, attributes = nil)
    unless action.present?
      create_loggings(@company, 'Gusto', 404, 'Action missing', {message: 'Select action i.e. create, update, activate etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Gusto', 404, "Gusto credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'Gusto', 404, "Gusto filters are not for user(#{@user.id}) - #{action}")
      return
    end

    if (Time.now.utc + 8.minutes >= @integration.expires_in&.to_time&.utc)
      status = HrisIntegrationsService::Gusto::AuthenticateApplication.new(@company, @integration.id).reauthorize
      if status == 'failed'
        create_loggings(@company, 'Gusto', 500, "Gusto credentials missing - #{action}")
        return
      end

      @integration.reload
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings
    ::HrisIntegrationsService::Gusto::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Gusto::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Gusto::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)
    return data_builder, params_builder
  end

  def create_profile
    return unless @user.reload.gusto_id.blank?
    data_builder, params_builder = init_data_and_params_builder
    ::HrisIntegrationsService::Gusto::CreateSaplingProfileInGusto
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.reload.gusto_id.present?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Gusto::UpdateSaplingProfileInGusto
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def terminate_profile
    return unless @user.reload.gusto_id.present?
    data_builder, params_builder = init_data_and_params_builder
    
    ::HrisIntegrationsService::Gusto::TerminateSaplingProfileInGusto
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes)
    when 'terminate'
      terminate_profile
    end

  end

  def helper_service
    ::HrisIntegrationsService::Gusto::Helper.new
  end
end