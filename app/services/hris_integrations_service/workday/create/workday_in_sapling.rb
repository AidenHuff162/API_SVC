class HrisIntegrationsService::Workday::Create::WorkdayInSapling < ApplicationService
  include HrisIntegrationsService::Workday::Logs
  include HrisIntegrationsService::Workday::Exceptions

  attr_reader :company, :user_params, :custom_field_params, :pending_hires, :helper_object, :pending_hire_params

  delegate :create_custom_field_options, :manage_user_current_stage,
           :user_cf_params_hash, :manage_user_on_create_update, to: :helper_object

  delegate :manage_terminated_employment_status_table_snapshot, :manage_employment_status_custom_table,
           to: :manage_integration_service

  def initialize(company, user_params, custom_field_params, helper_object)
    @helper_object, @company, @user_params = helper_object, company, user_params
    @pending_hires, @custom_field_params = company.pending_hires, custom_field_params
    @pending_hire_params = build_pending_hire_params
  end

  def call
    validate_presence!('Start Date', user_params[:start_date])
    actual_start_date = user_params.delete(:actual_start_date)
    if (user = fetch_user)
      update_existing_user(user) unless user.incomplete?
    else
      should_create_pending_hire?(actual_start_date) ? create_sapling_pending_hire : create_sapling_profile
    end
  end

  private

  def fetch_user
    user, users = nil, company.users
    [user_params[:email], user_params[:personal_email]].compact.each do |email|
      user ||= users.find_by('email ILIKE ? OR personal_email ILIKE ?', email, email)
    end
    user ||= users.find_by(workday_id: user_params[:workday_id]) if user_params[:workday_id].present?
    user
  end

  def update_existing_user(user)
    HrisIntegrationsService::Workday::Update::WorkdayInSapling.call(user, user_params, custom_field_params, helper_object)
    user.pending_hire.update!(pending_hire_params) if (user.pending_hire.deleted_at.blank? rescue nil)
  end

  def should_create_pending_hire?(actual_start_date)
    actual_start_date.try(:>, company.time.to_date) && user_params[:workday_id_type] == 'Employee_ID'
  end

  def create_sapling_pending_hire
    begin
      create_custom_field_options(company, custom_field_params)
      (pending_hire = fetch_pending_hire(pending_hire_params))&.update!(pending_hire_params)
      pending_hire ||= pending_hires.create!(pending_hire_params)
      success_log("Created/Updated the pending hire with id: #{pending_hire.id} in Sapling", {}, pending_hire_params)
    rescue Exception => @error
      error_log("Unable to Create/Update Pending Hire with id: #{pending_hire&.id} in Sapling", {params: pending_hire_params})
    end
  end

  def build_termination_params(user)
    {
      termination_type: user.termination_type,
      eligible_for_rehire: user.eligible_for_rehire,
      last_day_worked: user.last_day_worked,
      termination_date: user.termination_date
    }.compact
  end

  def create_sapling_profile
    begin
      profile_image = user_params.delete(:image)
      user_params[:onboard_email] = user_params[:email].present? ? 'company' : 'personal'
      user_params[:email] ||= user_params[:personal_email]
      user_params[:password] = 'Simpl3BILLPa4!' if %w[billcomsandbox billcomsandbox2].include?(company.subdomain)
      (user = company.users.create!(user_params.merge(skip_org_chart_callback: true))).save_profile_image(profile_image)

      manage_user_current_stage(user)
      manage_user_on_create_update(user, user_params, custom_field_params)
      if user.termination_date.blank?
        manage_employment_status_custom_table(user, user_cf_params_hash(user_params, custom_field_params))
      else
        manage_terminated_employment_status_table_snapshot(user, build_termination_params(user))
      end
      destroy_pending_hire(user)
      msg = "Created the user with id: #{user.id} in Sapling"
      success_log(msg, {}, user_cf_params_hash(user_params, custom_field_params))
    rescue Exception => @error
      msg = "Unable to create Sapling profile with #{user.present? ? "user id: (#{user.id})" : "workday id: (#{user_params[:workday_id]})"}"
      error_log(msg, {}, {params: user_cf_params_hash(user_params, custom_field_params)})
    end
  end

  def fetch_pending_hire(params)
    pending_hires.find_by(workday_id: params[:workday_id], workday_id_type: params[:workday_id_type])
  end

  def destroy_pending_hire(user)
    begin
      return if (pending_hire = pending_hire_by_email_wid(user)).blank?

      pending_hire.update_column(:user_id, user.id)
      pending_hire.destroy!
    rescue Exception => @error
      error_log("Unable to destroy pending hire with id: (#{pending_hire&.id}) in Sapling", {params: pending_hire})
    end
  end

  def pending_hire_by_email_wid(user)
    pending_hires.find_by(workday_id: user.workday_id) ||
      pending_hires.find_by('lower(personal_email) IN (?)', [user[:personal_email], user[:email]])
  end

  def manage_integration_service
    IntegrationsService::ManageIntegrationCustomTables.new(company, nil, 'workday')
  end

  def build_pending_hire_params
    user_params
      .except(:email, :actual_start_date)
      .merge(custom_fields: custom_field_params, employee_type: custom_field_params[:employment_status])
  end
end
