class HrisIntegrationsService::Workday::Update::WorkdayInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  attr_reader :user, :user_params, :custom_field_params, :company, :helper_object

  delegate :manage_user_current_stage, :manage_user_on_create_update,
           :user_cf_params_hash, to: :helper_object

  delegate :manage_employment_status_custom_table, to: :manage_integration_service

  def initialize(user, user_params, custom_field_params, helper_object)
    @helper_object = helper_object
    @user = user
    @company = user.company # for logging
    @user_params = user_params
    @custom_field_params = custom_field_params
  end

  def call
    update_sapling_profile
  end

  private

  def update_sapling_profile
    begin
      profile_image = user_params.delete(:image)
      user_params.delete(:state) if user_params[:state] == 'inactive' # state managed termination upon inactive
      termination_params = termination_params_hash
      original_user = user.dup
      rehire_user! if rehired?
      user.update!(user_params.merge(skip_org_chart_callback: true))
      return if user.blank?

      user.save_profile_image(profile_image)
      manage_user_current_stage(user) if should_update_current_stage
      manage_user_on_create_update(user, user_params, custom_field_params)
      manage_employment_status_custom_table(user, user_cf_params_hash(user_params, custom_field_params)) if termination_params.blank?
      terminate_user_if_applied(termination_params)
      create_rehire_snapshot if user_params[:is_rehired]
      Inbox::UpdateScheduledEmail.new.update_scheduled_user_emails(user, original_user)
      success_log("Updated the user with id: #{user.id} in Sapling",
                  {}, user_cf_params_hash(user_params, custom_field_params))

    rescue Exception => @error
      error_log("Unable to update Sapling profile with user id: (#{user.id})",
                { params: user_cf_params_hash(user_params, custom_field_params) })
    end
  end

  def termination_params_hash
    {
      termination_type: user_params.delete(:termination_type),
      eligible_for_rehire: user_params.delete(:eligible_for_rehire),
      last_day_worked: user_params.delete(:last_day_worked),
      termination_date: user_params.delete(:termination_date)
    }.compact
  end

  def terminate_user_if_applied(termination_params)
    return if termination_params.blank? && user.termination_date.present?
    HrisIntegrationsService::Workday::Terminate::WorkdayInSapling.call(user, termination_params, helper_object)
  end

  def should_update_current_stage
    %w[invited preboarding].exclude?(user.current_stage)
  end

  def manage_integration_service
    IntegrationsService::ManageIntegrationCustomTables.new(user.company, nil, 'workday')
  end

  def rehired?
    user.departed? && (user_params[:state] == 'active')
  end

  def create_rehire_snapshot
    CustomTables::CustomTableSnapshotManagement.new.rehiring_management(user, nil)
  end

  def rehire_user!
    return unless user.termination_date.present? && user.inactive?

    user_params[:is_rehired] = true
    user.rehire!
    user.update!(last_day_worked: nil, termination_type: nil, termination_date: nil,
                 eligible_for_rehire: nil, is_rehired: true, state: :active, remove_access_state: :pending)
    Interactions::Users::SendInvite.new(user.id, true).perform
    SsoIntegrations::Gsuite::ReactivateGsuiteProfile.perform_async(user.id) unless user.gsuite_account_exists
    user.reset_pto_balances
  end

end
