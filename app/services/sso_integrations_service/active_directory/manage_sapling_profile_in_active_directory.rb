class SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, to: :helper_service

  def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company)

    parameter_mappings = init_parameter_mappings
  end

  def perform(action, attributes = nil)
    unless action.present?
      create_loggings(@company, 'Active Directory', 404, 'Action missing', {message: 'Select action i.e. create_and_update, or update etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'Active Directory', 404, "Active Directory credentials missing - #{action}")
      return
    end

    if (Time.now.utc + 30.minutes >= @integration.expires_in.to_time.utc)
      status = ::SsoIntegrationsService::ActiveDirectory::AuthenticateApplication.new(@company).reauthorize
      if status == 'failed'
        create_loggings(@company, 'Active Directory', 500, "Active Directory credentials missing - #{action}")
        return
      end

      @integration.reload
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings
    ::SsoIntegrationsService::ActiveDirectory::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::SsoIntegrationsService::ActiveDirectory::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::SsoIntegrationsService::ActiveDirectory::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def create_and_update_profile
    return unless @user.reload.active_directory_object_id.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::SsoIntegrationsService::ActiveDirectory::CreateSaplingProfileInActiveDirectory
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.reload.active_directory_object_id.present? && attributes.present? && @integration.enable_update_profile
    data_builder, params_builder = init_data_and_params_builder

    ::SsoIntegrationsService::ActiveDirectory::UpdateSaplingProfileInActiveDirectory
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def execute(action, attributes)
    case action.downcase
    when 'create_and_update'
      create_and_update_profile
    when 'update'
      update_profile(attributes) 
    end
  end

  def helper_service
    ::SsoIntegrationsService::ActiveDirectory::Helper.new
  end
end
