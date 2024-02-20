class HrisIntegrationsService::Trinet::ManageSaplingProfileInTrinet
	attr_reader :company, :user, :integration, :data_builder, :params_builder

  delegate :create_loggings, :notify_slack, :fetch_integration, :is_integration_valid?, :saved_integration_credentials, :can_integrate_profile?, to: :helper_service

	def initialize(user)
    @user = user
    @company = user.company
    @integration = fetch_integration(@company, @user)
    parameter_mappings = init_parameter_mappings
  end

	def perform(action, attribute = nil)
    @integration.in_progress!

    unless action.present?
      create_loggings(@company, @integration, 'Trinet', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, @integration, 'Trinet', 404, "Trinet filters are not for user(#{@user.id}) - #{action}")
      return
    end
    if @integration.access_token.blank? || (Time.now.utc + 40.minutes >= @integration.expires_in&.to_time&.utc)
      status = manage_access_token(action)
      return if status == 'failed'
    end
    
    unless is_integration_valid?(@integration)
      create_loggings(@company, @integration, 'Trinet', 404, "Trinet credentials missing - #{action}")
      return
    end

    execute(action, attribute)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings
    ::HrisIntegrationsService::Trinet::ParamsMapper.new.build_parameter_mappings
  end
 
  def init_data_builder(parameter_mappings)
    ::HrisIntegrationsService::Trinet::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::HrisIntegrationsService::Trinet::ParamsBuilder.new(parameter_mappings)
  end

  def init_job_reclassification_params
    ::HrisIntegrationsService::Trinet::ParamsMapper.new.build_job_classification_params
  end

  def init_personal_params
    ::HrisIntegrationsService::Trinet::ParamsMapper.new.build_personal_params
  end

  def init_name_params
    ::HrisIntegrationsService::Trinet::ParamsMapper.new.build_name_params
  end

  def init_data_and_params_builder(action, section=nil)
    if action == 'create'
      parameter_mappings = init_parameter_mappings
    else 
      if section == 'job_reclassification'
        parameter_mappings = init_job_reclassification_params
      elsif section == 'personal'
        parameter_mappings = init_personal_params
      elsif section == 'name'
          parameter_mappings = init_name_params
      end
    end

    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def manage_access_token(action)
    response = HrisIntegrationsService::Trinet::Endpoint.new.generate_access_token(@integration)
    if response.code.to_s != '200'
      create_loggings(@company, @integration, 'Trinet', response.code, "Trinet access token generation failed - #{action}")
      return 'failed'
    else 
      saved_integration_credentials(response, @integration)
    end

    @integration.reload
    return 'success'
  end

  def create_profile
    data_builder, params_builder = init_data_and_params_builder('create') 
    ::HrisIntegrationsService::Trinet::CreateSaplingProfileInTrinet
      .new( @company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attribute)
    return unless @user.reload.trinet_id.present? && attribute.present?

    section = (init_job_reclassification_params.values.pluck(:name) & [attribute].flatten).empty? ? nil : 'job_reclassification'
    section = (init_personal_params.values.pluck(:name) & [attribute].flatten).empty? ? nil : 'personal' unless section.present?
    section = (init_name_params.values.pluck(:name) & [attribute].flatten).empty? ? nil : 'name' unless section.present?

    return unless section.present?
    attribute = (["effective date"] << attribute).flatten
    attribute = (["country"] << attribute).flatten if section == 'personal'
    attribute = ['effective date', 'first name', 'last name', 'name type'] if section == 'name'
    
    data_builder, params_builder = init_data_and_params_builder('update', section)
    ::HrisIntegrationsService::Trinet::UpdateSaplingProfileInTrinet
      .new(@company, @user, @integration, data_builder, params_builder, attribute, section).perform
  end

  def execute(action, attributes=nil)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes)
    end
  end

  def helper_service
    HrisIntegrationsService::Trinet::Helper.new
  end

end	
