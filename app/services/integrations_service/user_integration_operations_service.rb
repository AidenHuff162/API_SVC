class IntegrationsService::UserIntegrationOperationsService
  include HrisIntegrationsService::Workday::Logs

  attr_reader :company, :user, :integrations_list, :options

  def initialize(user, included_list = [], excluded_list = [], options = {})
    @user = user
    @company = user.company
    @integrations_list = fetch_integrations_list(included_list, excluded_list)
    @options = options
  end

  def perform(action, params = nil)
    execute(action, params) if integrations_list.present? || ['sync', 'create_account'].include?(action) 
  end

  private

  def execute(action, params = nil)
    case action.downcase
    when 'create'
      create_integration_profiles
    when 'update'
      update_integration_profiles(params)
    when 'deactivate'
      deactivate_integration_profiles
    when 'delete'
      delete_integration_profiles
    when 'reactivate'
      reactivate_integration_profiles
    when 'sync'
      sync_now(params)
    when 'create_account'
      create_account(params)
    end
  end

  def create_integration_profiles
    if user.learn_upon_id.blank? && integrations_list.include?( 'learn_upon' )
      ::LearningDevelopmentIntegrations::LearnUpon::CreateLearnUponUserFromSaplingJob.perform_async(user.id)
    end

    if user.lessonly_id.blank? && integrations_list.include?( 'lessonly' )
      ::LearningDevelopmentIntegrations::Lessonly::CreateLessonlyUserFromSaplingJob.perform_async(user.id)
    end

    if user.namely_id.blank? && integrations_list.include?( 'namely' )
      ::HrisIntegrations::Namely::CreateNamelyUserFromSaplingJob.perform_async(user.id)
    end

    if user.deputy_id.blank? && integrations_list.include?( 'deputy' )
      ::HrisIntegrations::Deputy::CreateDeputyUserFromSaplingJob.perform_async(user.id)
    end

    if user.trinet_id.blank? && integrations_list.include?( 'trinet' )
      ::HrisIntegrations::Trinet::CreateTrinetUserFromSaplingJob.perform_async(user.id)
    end
    
    if user.fifteen_five_id.blank? && integrations_list.include?( 'fifteen_five' )
      ::PerformanceIntegrations::FifteenFive::CreateFifteenFiveUserFromSaplingJob.perform_async(user.id)
    end

    if user.peakon_id.blank? && integrations_list.include?( 'peakon' )
      ::PerformanceIntegrations::Peakon::CreatePeakonUserFromSaplingJob.perform_async(user.id)
    end

    if user.paychex_id.blank? && integrations_list.include?( 'paychex' )
      ::HrisIntegrations::Paychex::CreatePaychexUserFromSaplingJob.perform_async(user.id)
    end

    if user.gusto_id.blank? && integrations_list.include?( 'gusto' ) && company.gusto_feature_flag
      ::HrisIntegrations::Gusto::CreateGustoUserFromSaplingJob.perform_async(user.id)
    end
    
    if user.lattice_id.blank? && integrations_list.include?( 'lattice' )
      ::PerformanceIntegrations::Lattice::CreateLatticeUserFromSaplingJob.perform_async(user.id)
    end

    if integrations_list.include?( 'kallidus_learn' )
      ::LearningDevelopmentIntegrations::Kallidus::CreateKallidusUserFromSaplingJob.perform_in(10.seconds, user.id)
    end

    if user.paylocity_id.blank? && integrations_list.include?( 'paylocity' )
      ::HrisIntegrations::Paylocity::CreatePaylocityUserFromSaplingJob.perform_async(user.id)
    end

    if user.xero_id.blank? && integrations_list.include?( 'xero' )
      HrisIntegrationsService::Xero::ManageSaplingUserInXero.new(user).perform('create')
    end

  end

  def update_integration_profiles(params = nil)
    if user.learn_upon_id.present? && integrations_list.include?( 'learn_upon' )
      attributes = construct_attributes('learn_upon', params)
      ::LearningDevelopmentIntegrations::LearnUpon::UpdateLearnUponUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end

    if user.lessonly_id.present? && integrations_list.include?( 'lessonly' )
      attributes = construct_attributes('lessonly', params)
      ::LearningDevelopmentIntegrations::Lessonly::UpdateLessonlyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end

    if user.namely_id.present? && integrations_list.include?( 'namely' )
      attributes = construct_attributes('namely', params)
      ::HrisIntegrations::Namely::UpdateNamelyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end

    if user.deputy_id.present? && integrations_list.include?( 'deputy' )
      attributes = construct_attributes('deputy', params)
      ::HrisIntegrations::Deputy::UpdateDeputyUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end
    
    if user.trinet_id.present? && integrations_list.include?( 'trinet' )
      attributes = construct_attributes('trinet', params)
      ::HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end

    if user.fifteen_five_id.present? && integrations_list.include?( 'fifteen_five' )
      attributes = construct_attributes('fifteen_five', params)
      ::PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id}) if attributes.present?
    end

    if user.peakon_id.present? && integrations_list.include?( 'peakon' )
      attributes = construct_attributes('peakon', params)
      attributes.try(:each) do |attribute|
        ::PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attribute: attribute})
      end
    end

    if user.gusto_id.present? && integrations_list.include?( 'gusto' ) && company.gusto_feature_flag
      attributes = construct_attributes('gusto', params)
      ::HrisIntegrations::Gusto::UpdateGustoUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end
    
    if user.lattice_id.present? && integrations_list.include?( 'lattice' )
      attributes = construct_attributes('lattice', params)
      ::PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id}) if attributes.present?
    end
        
    if user.paychex_id.present? && integrations_list.include?( 'paychex' )
      attributes = construct_attributes('paychex', params)
      ::HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.perform_async(user.id, attributes) if attributes.present?
    end

    if !user.super_user && !user.incomplete? && integrations_list.include?( 'kallidus_learn' )
      attributes = construct_attributes('kallidus_learn', params)
      ::LearningDevelopmentIntegrations::Kallidus::UpdateKallidusUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id, attributes: attributes}) if attributes.present?
    end
        
    if user.paylocity_id.present? && integrations_list.include?( 'paylocity' )
      attributes = construct_attributes('paylocity', params)
      ::HrisIntegrations::Paylocity::UpdatePaylocityUserFromSaplingJob.perform_in(5.seconds, user.id, attributes) if attributes.present?
    end
    if user.xero_id.present? && integrations_list.include?( 'xero' )
      attributes = construct_attributes('xero', params)
      SendUpdatedEmployeeToXeroJob.perform_later(user, attributes) if attributes.present?
    end

    if user.workday_id.present? && integrations_list.include?('workday')
      updated_field_names = []
      %w[personal_email first_name last_name title email preferred_name].each do |cf_name|
        updated_field_names << cf_name.gsub('_', ' ') if should_add_cf_name_for_workday?(params, cf_name)
      end
      HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.set(wait: 2.minutes).perform_later(user.id, updated_field_names) if updated_field_names.present?
      if params[:is_profile_image_updated]
        HrisIntegrations::Workday::UpdateWorkdayUserFromSaplingJob.perform_later(user.id, ['profile image'])
        log_to_wd_teams_channel(user, "Status: [image_present: #{user.reload.profile_image&.file&.url.present?}]", 'Workday Bulk Update Logs - Prod') unless params[:profile_image]&.dig(:remove_file)
      end
    end
  end

  def should_add_cf_name_for_workday?(params, cf_name)
    prev_user_attrs, opt_params = options[:tmp_user], options[:params] # prev_user_attrs: user attributes before assigning values
    param_value, opt_param_value = params&.dig(cf_name.to_sym), opt_params&.dig(cf_name.to_sym)
    (param_value && user.attributes[cf_name] != param_value) || (opt_param_value && workday_custom_snapshot_name?(cf_name) && prev_user_attrs[cf_name] != opt_param_value)
  end

  def workday_custom_snapshot_name?(cf_name)
    ['title'].include?(cf_name)
  end

  def deactivate_integration_profiles
    if user.learn_upon_id.present? && integrations_list.include?( 'learn_upon' )
      ::LearningDevelopmentIntegrations::LearnUpon::DeactivateLearnUponUserFromSaplingJob.perform_async(user.id)
    end

    if user.lessonly_id.present? && integrations_list.include?( 'lessonly' )
      ::LearningDevelopmentIntegrations::Lessonly::DeactivateLessonlyUserFromSaplingJob.perform_async(user.id)
    end

    if user.namely_id.present? && integrations_list.include?( 'namely' )
      ::HrisIntegrations::Namely::TerminateNamelyUserFromSaplingJob.perform_in(20.seconds, user.id)
    end

    if user.deputy_id.present? && integrations_list.include?( 'deputy' )
      ::HrisIntegrations::Deputy::TerminateDeputyUserFromSaplingJob.perform_async(user.id)
    end

    if user.fifteen_five_id.present? && integrations_list.include?( 'fifteen_five' )
      ::PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob.perform_in(20.seconds, {user_id: user.id})
    end

    if user.peakon_id.present? && integrations_list.include?( 'peakon' )
      ::PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.perform_in(20.seconds, {user_id: user.id, attribute: ['termination date', 'termination type', 'state']})
    end

    if user.gusto_id.present? && integrations_list.include?( 'gusto' ) && company.gusto_feature_flag
      ::HrisIntegrations::Gusto::TerminateGustoUserFromSaplingJob.perform_in(20.seconds, user.id)
    end
    
    if user.lattice_id.present? && integrations_list.include?( 'lattice' )
      ::PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob.perform_in(20.seconds, {user_id: user.id})
    end

    if !user.super_user && !user.incomplete? && integrations_list.include?( 'kallidus_learn' )
      ::LearningDevelopmentIntegrations::Kallidus::DeactivateKallidusUserFromSaplingJob.perform_async(user.id)
    end
  end

  def delete_integration_profiles
    if user.fifteen_five_id.present? && integrations_list.include?( 'fifteen_five' )
      ::PerformanceIntegrations::FifteenFive::DeleteFifteenFiveUserFromSaplingJob.perform_async(user.dup)
    end

    if user.peakon_id.present? && integrations_list.include?( 'peakon' )
      ::PerformanceIntegrations::Peakon::DeletePeakonUserFromSaplingJob.perform_async(user.dup)
    end
  end

  def reactivate_integration_profiles
    if user.learn_upon_id.present? && integrations_list.include?( 'learn_upon' )
      ::LearningDevelopmentIntegrations::LearnUpon::ReactivateLearnUponUserFromSaplingJob.perform_async(user.id)
    end

    if user.lessonly_id.present? && integrations_list.include?( 'lessonly' )
      ::LearningDevelopmentIntegrations::Lessonly::ReactivateLessonlyUserFromSaplingJob.perform_async(user.id)
    end

    if user.deputy_id.present? && integrations_list.include?( 'deputy' )
      ::HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob.perform_async(user.id)
    end

    if user.lattice_id.present? && integrations_list.include?( 'lattice' )
      ::PerformanceIntegrations::Lattice::UpdateLatticeUserFromSaplingJob.perform_in(5.seconds, {user_id: user.id})
    end

    if !user.super_user && integrations_list.include?( 'kallidus_learn' )
      ::LearningDevelopmentIntegrations::Kallidus::ReactivateKallidusUserFromSaplingJob.perform_async(user.id)
    end
  end

  def sync_now(params=nil)
    instances = fetch_integration_instance_by_inventory(params)
    instances.find_each do |instance|
    case instance.api_identifier
      when 'learn_upon'
        ::LearningDevelopmentIntegrations::LearnUpon::UpdateSaplingUserFromLearnUponJob.perform_async(@company.id)
      when 'lessonly'
        ::LearningDevelopmentIntegrations::Lessonly::UpdateSaplingUserFromLessonlyJob.perform_async(@company.id)
      when 'fifteen_five'
        ::PerformanceIntegrations::FifteenFive::UpdateSaplingUserFromFifteenFiveJob.perform_async(@company.id)
      when 'peakon'
        ::PerformanceIntegrations::Peakon::UpdateSaplingUserFromPeakonJob.perform_async(@company.id)
      when 'lattice'
        ::PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob.perform_async(@company.id)
      when 'team_spirit'
        ::TeamSpirit::UpdateSaplingUserToTeamSpiritJob.perform_async(instance.id)
      when 'namely'
        ::Integrations::PayrollIntegrationChange.perform_async(@company.id, 'namely', false)
      when 'xero'
        ::HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob.perform_async(@company.id)
      when 'workday'
        HrisIntegrations::Workday::UpdateSaplingUsersFromWorkdayJob.perform_async(@company.id)
      when 'smart_recruiters'
        ImportPendingHiresFromSmartRecruitersJob.perform_later(@company.id)
      when 'bamboo_hr'
        ::HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob.perform_later(@company.id, true) if @company.id != 64
      when 'adp_wfn_us'
        ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(@company.id, 'adp_wfn_us')
      when 'adp_wfn_can'
        ReceiveUpdatedEmployeeFromAdpWorkforceNowJob.perform_later(@company.id, 'adp_wfn_can')
      end
    end
  end

  def create_account(api_identifier=nil)
    case api_identifier  
    when 'gusto' 
      ::HrisIntegrationsService::Gusto::CreateCompany.new(company, user).create_company
    end
  end

  def apply_to_location?(filters)
    location_ids = filters['location_id']
    location_ids.include?('all') || (location_ids.present? && user.location_id.present? && location_ids.include?(user.location_id))
  end

  def apply_to_team?(filters)
    team_ids = filters['team_id']
    team_ids.include?('all') || (team_ids.present? && user.team_id.present? && team_ids.include?(user.team_id))
  end

  def apply_to_employee_type?(filters)
    employee_types = filters['employee_type']
    employee_types.include?('all') || (employee_types.present? && user.employee_type_field_option&.option.present? && employee_types.include?(user.employee_type_field_option&.option))
  end

  def is_integration_applied?(integration)
    return unless integration.filters.present?
    apply_to_location?(integration.filters) && apply_to_team?(integration.filters) && apply_to_employee_type?(integration.filters)
  end

  def fetch_integrations_list(included_list, excluded_list)
    integrations_list = []

    integrations = @company.integration_instances.where(api_identifier: [ 'learn_upon', 'lessonly', 'deputy', 'fifteen_five', 'peakon', 'trinet', 'gusto', 'lattice', 'paychex', 'kallidus_learn', 'paylocity', 'namely', 'xero', 'workday', 'smart_recruiters'])
    integrations = integrations.where(api_identifier: included_list) if included_list.present?
    integrations = integrations.where.not(api_identifier: excluded_list) if excluded_list.present?
    
    integrations.find_each do |integration|
      is_integration_applied?(integration) ? integrations_list.push(integration.api_identifier) : create_loggings(company, integration.api_identifier , 424, "#{integration.api_identifier} filters are not for user (#{user.id})")
    end

    return integrations_list
  end

  def fetch_integration_instance_by_inventory(inventory_id)
    @company.integration_instances.where(integration_inventory_id: inventory_id)
  end

  def construct_attributes(integration_name, params)
    ::IntegrationsService::IntegrationAttributesConstructorService.new(user, params, options).perform(integration_name)
  end

  def create_loggings(company, integration_name, state, action, result = {}, api_request = 'No Request')
    LoggingService::IntegrationLogging.new.create(
      company,
      integration_name,
      action,
      api_request,
      result,
      state.to_s
    )
  end
end
