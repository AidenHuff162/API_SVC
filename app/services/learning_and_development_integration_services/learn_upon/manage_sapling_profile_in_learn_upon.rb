class LearningAndDevelopmentIntegrationServices::LearnUpon::ManageSaplingProfileInLearnUpon
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
      create_loggings(@company, 'LearnUpon', 404, 'Action missing', {message: 'Select action i.e. create, update etc'})
      return
    end

    unless is_integration_valid?(@integration)
      create_loggings(@company, 'LearnUpon', 404, "LearnUpon credentials missing - #{action}")
      return
    end

    unless can_integrate_profile?(@integration, @user)
      create_loggings(@company, 'LearnUpon', 424, "LearnUpon filters are not for user (#{@user.id}) - #{action}")
      return
    end

    execute(action, attributes)
    @integration.update_column(:synced_at, DateTime.now) if @integration.present?
  end

  private

  def init_parameter_mappings   
    ::LearningAndDevelopmentIntegrationServices::LearnUpon::ParamsMapper.new.build_parameter_mappings
  end

  def init_data_builder(parameter_mappings)
    ::LearningAndDevelopmentIntegrationServices::LearnUpon::DataBuilder.new(parameter_mappings)
  end

  def init_params_builder(parameter_mappings)
    ::LearningAndDevelopmentIntegrationServices::LearnUpon::ParamsBuilder.new(parameter_mappings)
  end

  def init_data_and_params_builder
    parameter_mappings = init_parameter_mappings
    data_builder = init_data_builder(parameter_mappings)
    params_builder = init_params_builder(parameter_mappings)

    return data_builder, params_builder
  end

  def create_profile
    return unless @user.learn_upon_id.blank?
    data_builder, params_builder = init_data_and_params_builder

    ::LearningAndDevelopmentIntegrationServices::LearnUpon::CreateSaplingProfileInLearnUpon
      .new(@company, @user, @integration, data_builder, params_builder).perform
  end

  def update_profile(attributes)
    return unless @user.learn_upon_id.present?
    data_builder, params_builder = init_data_and_params_builder

    ::LearningAndDevelopmentIntegrationServices::LearnUpon::UpdateSaplingProfileInLearnUpon
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def deactivate_profile
    return unless @user.learn_upon_id.present?
    data_builder, params_builder = init_data_and_params_builder
    attributes = []

    attributes.push('state') if @user.inactive?
    attributes.push('last day worked') if @user.last_day_worked.present? && @user.last_day_worked > Date.today

    return unless attributes.present?

    ::LearningAndDevelopmentIntegrationServices::LearnUpon::UpdateSaplingProfileInLearnUpon
      .new(@company, @user, @integration, data_builder, params_builder, attributes).perform
  end

  def execute(action, attributes)
    case action.downcase
    when 'create'
      create_profile
    when 'update'
      update_profile(attributes)
    when 'deactivate'
      deactivate_profile
    when 'reactivate'
      update_profile([ 'all' ])
    end
  end

  def helper_service
    LearningAndDevelopmentIntegrationServices::LearnUpon::Helper.new
  end
end