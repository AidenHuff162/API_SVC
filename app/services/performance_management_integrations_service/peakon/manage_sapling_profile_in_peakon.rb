class PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :can_integrate_profile?, to: :helper_service

  def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company)

    parameter_mappings = init_parameter_mappings
  end

  def perform(action, attributes = nil)
    unless action.present?
      create_loggings(@company, 'Peakon', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Peakon', 404, "Peakon credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'Peakon', 424, "Peakon filters are not for user (#{@user.id}) - #{action}")
      return
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings   
    ::PerformanceManagementIntegrationsService::Peakon::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::PerformanceManagementIntegrationsService::Peakon::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::PerformanceManagementIntegrationsService::Peakon::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def create_profile
    return unless @user.reload.peakon_id.blank?
    data_builder, params_builder = init_data_and_params_builder

      ::PerformanceManagementIntegrationsService::Peakon::CreateSaplingProfileInPeakon
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def delete_profile
    return unless @user.reload.peakon_id.present? && @integration.can_delete_profile.present?
    
    ::PerformanceManagementIntegrationsService::Peakon::DeleteSaplingProfileInPeakon
    .new(@company, @user, @integration).perform
  end

  def update_profile(attributes)
    return unless @user.reload.peakon_id.present?
    data_builder, params_builder = init_data_and_params_builder

    ::PerformanceManagementIntegrationsService::Peakon::UpdateSaplingProfileInPeakon
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'delete'
      delete_profile
    when 'update'
      update_profile(attributes)
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::Peakon::Helper.new
  end
end