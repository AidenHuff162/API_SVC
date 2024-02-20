class PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :can_integrate_profile?, to: :helper_service

  def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company)

    parameter_mappings = init_parameter_mappings
  end

  def perform(action)
    unless action.present?
      @integration.update_columns(synced_at: DateTime.now, sync_status: 'failed') if @integration.present?
      create_loggings(@company, 'Fifteen Five', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless is_integration_valid?(@integration)
      @integration.update_columns(synced_at: DateTime.now, sync_status: 'failed') if @integration.present?
      create_loggings(@company, 'Fifteen Five', 404, "Fifteen Five credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      @integration.update_columns(synced_at: DateTime.now, sync_status: 'failed') if @integration.present?
      create_loggings(@company, 'Fifteen Five', 424, "Fifteen Five filters are not for user (#{@user.id}) - #{action}")
      return
    end

    execute(action)
  end

  private

  def init_parameter_mappings
    ::PerformanceManagementIntegrationsService::FifteenFive::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::PerformanceManagementIntegrationsService::FifteenFive::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::PerformanceManagementIntegrationsService::FifteenFive::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def create_profile
    return unless @user.reload.fifteen_five_id.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::PerformanceManagementIntegrationsService::FifteenFive::CreateSaplingProfileInFifteenFive
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile
    return unless @user.reload.fifteen_five_id.present?
    data_builder, params_builder = init_data_and_params_builder

    ::PerformanceManagementIntegrationsService::FifteenFive::UpdateSaplingProfileInFifteenFive
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def delete_profile
    dont_delete_profile = @user.reload.fifteen_five_id.blank? && @integration.can_delete_profile.blank? rescue true
    return if dont_delete_profile
    ::PerformanceManagementIntegrationsService::FifteenFive::DeleteSaplingProfileInFifteenFive
      .new(@company, @user, @integration).perform
  end

  def execute(action)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile
    when 'delete'
      delete_profile
    end
  end

  def helper_service
    PerformanceManagementIntegrationsService::FifteenFive::Helper.new
  end
end