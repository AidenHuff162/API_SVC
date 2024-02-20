class HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, :fetch_integration, :is_integration_valid?, :can_integrate_profile?, to: :helper_service

  def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company)

    parameter_mappings = init_parameter_mappings
  end

  def perform(action, attributes = nil)
    @integration.in_progress!
    
    unless action.present?
      create_loggings(@company, 'Deputy', 404, 'Action missing', {message: 'Select action i.e. create, update, activate etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Deputy', 404, "Deputy credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'Deputy', 404, "Deputy filters are not for user(#{@user.id}) - #{action}")
      return
    end

    if (Time.now.utc + 45.minutes >= @integration.expires_in&.to_time&.utc)
      status = HrisIntegrationsService::Deputy::AuthenticateApplication.new(@company).reauthorize
      if status == 'failed'
        create_loggings(@company, 'Deputy', 500, "Deputy credentials missing - #{action}")
        return
      end

      @integration.reload
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings
    ::HrisIntegrationsService::Deputy::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Deputy::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Deputy::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def create_profile
    return unless @user.reload.deputy_id.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Deputy::CreateSaplingProfileInDeputy
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.reload.deputy_id.present? && attributes.present? && @user.departed?.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Deputy::UpdateSaplingProfileInDeputy
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def terminate_profile
    return unless @user.reload.deputy_id.present?

    ::HrisIntegrationsService::Deputy::TerminateSaplingProfileInDeputy
      .new(@company, @user, @integration).perform
  end

  def delete_profile
    return unless @user.reload.deputy_id.present? && @integration.can_delete_profile.present?

    ::HrisIntegrationsService::Deputy::DeleteSaplingProfileInDeputy
      .new(@company, @user, @integration).perform
  end

  def rehire_profile
    return unless @user.reload.deputy_id.present?

    ::HrisIntegrationsService::Deputy::RehireSaplingProfileInDeputy
      .new(@company, @user, @integration).perform
  end

  def rehire_and_update_profile
    return unless @user.reload.deputy_id.present?
    data_builder, params_builder = init_data_and_params_builder

    ::HrisIntegrationsService::Deputy::RehireSaplingProfileInDeputy.new(@company, @user, @integration, data_builder, params_builder).perform(true)
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes) 
    when 'terminate'
      terminate_profile
    when 'delete'
      delete_profile
    when 'rehire'
      rehire_profile
    when 'rehire_and_update'
      rehire_and_update_profile
    when 'terminate_and_delete'
      terminate_profile
      delete_profile if @integration.can_delete_profile.present?
    end
  end

  def helper_service
    HrisIntegrationsService::Deputy::Helper.new
  end
end