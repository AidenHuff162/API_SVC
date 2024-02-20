class LearningAndDevelopmentIntegrationServices::Kallidus::ManageSaplingProfileInKallidus
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
      create_loggings(@company, 'KallidusLearn', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'KallidusLearn', 404, "KallidusLearn credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'KallidusLearn', 424, "KallidusLearn filters are not for user (#{@user.id}) - #{action}")
      return
    end

    create_profile
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings   
    ::LearningAndDevelopmentIntegrationServices::Kallidus::ParamsMapper.new.build_parameter_mappings(company.subdomain, integration)
  end

  def init_data_builder(parameter_mappings)
    ::LearningAndDevelopmentIntegrationServices::Kallidus::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::LearningAndDevelopmentIntegrationServices::Kallidus::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)
    return data_builder, params_builder
  end

  def create_profile
    data_builder, params_builder = init_data_and_params_builder

    ::LearningAndDevelopmentIntegrationServices::Kallidus::CreateSaplingProfileInKallidus
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.kallidus_learn_id.present?
    data_builder, params_builder = init_data_and_params_builder
    
    ::LearningAndDevelopmentIntegrationServices::Kallidus::UpdateSaplingProfileInKallidus
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def deactivate_profile
    return unless @user.kallidus_learn_id.present?
    data_builder, params_builder = init_data_and_params_builder
    attributes = []

    if @user.inactive?
      attributes.push('state')
      attributes.push('last day worked') if @user.last_day_worked.present?
    end

    return unless attributes.present?

    ::LearningAndDevelopmentIntegrationServices::Kallidus::UpdateSaplingProfileInKallidus
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def manage_user_update(action, attributes = nil)
    if @user.kallidus_learn_id.present?
      execute_action(action, attributes)
    elsif (@user.created_at_kallidus + 24.hour) < DateTime.now
      ::LearningAndDevelopmentIntegrationServices::Kallidus::ManageKallidusProfileInSapling.new(@company, @user&.guid).perform
      @user.reload
      
      if @user.kallidus_learn_id.present?
        execute_action(action, attributes)
      else
        create_loggings(@company, 'KallidusLearn', 404, "KallidusLearn user not imported in Learn - #{action}")
      end
    else
      create_profile
    end
  end

  def execute_action(action, attributes = nil)
    case action.downcase
    when 'update'
      update_profile(attributes)
    when 'deactivate'
      deactivate_profile
    end
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'deactivate'
      manage_user_update('deactivate')
    when 'update'
      manage_user_update('update', attributes)
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::Kallidus::Helper.new
  end
end