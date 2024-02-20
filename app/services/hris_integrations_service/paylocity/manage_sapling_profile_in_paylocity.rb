class HrisIntegrationsService::Paylocity::ManageSaplingProfileInPaylocity
  attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :fetch_integration, :is_integration_valid?, :can_integrate_profile?, to: :helper_service
  delegate :change_params_mapper_for_custom_field_mapping, to: :integrations_helper_service

  def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company, @user)
  end

  def perform(action, attributes=nil)
    unless action.present?
      create_loggings(@company, 'Action missing' , 404, {message: 'Select action i.e. create, update, activate etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, "Paylocity credentials missing - #{action}" , 404)
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, "Paylocity filters are not for user(#{@user.id}) - #{action}", 404)
      return
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings(action)
    if ( action == 'create' && ['onboarding_webpay', 'onboarding_only', 'one_way_onboarding_webpay'].include?(integration.integration_type)) || 
      ( action == 'update' && ['onboarding_webpay', 'web_pay_only', 'one_way_onboarding_webpay'].include?(integration.integration_type))
      ::HrisIntegrationsService::Paylocity::ParamsMapper.new.build_v1_parameter_mappings
    else
      ::HrisIntegrationsService::Paylocity::ParamsMapper.new.build_v2_parameter_mappings
    end
  end

  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Paylocity::DataBuilder.new(parameter_mappings, @company, @integration, @user)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Paylocity::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder(action)
    parameter_mappings = init_parameter_mappings(action)
    parameter_mappings = change_params_mapper_for_custom_field_mapping(parameter_mappings, @integration, @company)
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)
    return data_builder, params_builder
  end

  def create_profile
    return unless @user.reload.paylocity_id.blank? && @user.paylocity_onboard.blank?

    data_builder, params_builder = init_data_and_params_builder('create')
    ::HrisIntegrationsService::Paylocity::CreateSaplingProfileInPaylocity
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.reload.paylocity_id.present?
    
    data_builder, params_builder = init_data_and_params_builder('update')
    attributes.push('company number', 'paylocity id')

    ::HrisIntegrationsService::Paylocity::UpdateSaplingProfileInPaylocity
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def execute(action, attributes)
    case action
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes)
    end

  end

  def helper_service
    ::HrisIntegrationsService::Paylocity::Helper.new
  end

  def integrations_helper_service
    IntegrationCustomMappingHelper.new
  end
end