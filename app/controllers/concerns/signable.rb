module Signable
  extend ActiveSupport::Concern

  def create_user
    @resource = @company.users.new(user_params)
    @resource.save!
  end

  def check_subdomain
    params_subdomain = params[:subdomain]
    companies = Company.unscoped.all
    if companies.find_by_subdomain(params_subdomain).present?
      render json: { error: 'Subdomain Already Exists', status: 422}
    end
  end

  def check_email
    users = User.unscoped.all
    if users.find_by_email(params[:email]).present?
      render json: { error: 'Email Already Exists', status: 422}
    end
  end

  def validate_signup_flag
    if ENV["SIGNUP_FLAG"] != 'true'
      render json: { error: 'This route is not available', status: 422}
    end
  end

  def create_billing
    @company.create_billing(trial_start_date: Date.today, trial_end_date: get_trial_period_end)
  end

  def create_auth_token
    key = JsonWebToken.encode({resource_id: @resource.id}, Time.now + 50.seconds)
    @resource.update_column(:temp_auth_token, key)
    key
  end

  def verify_token
    @resource = current_company.users.last
    @resource.temp_auth_token.downcase == params['temp-token']
  end

  def user_sign_in
    @token = @resource.create_token
    @resource.save
    sign_in(:user, @resource, store: false, bypass: false)
  end

  def get_account_type
    account_type_param = Integer(params['at']) rescue 6
    account_type_param == 3 ? account_type_param : 6
  end

  def get_company_plan
    (Integer(params['p']) == 1 ? 1 : 0) rescue 0
  end

  def get_trial_period_end
    trial_period_param = Integer(params['tp']) rescue 14
    Date.today + (trial_period_param > -1 ? trial_period_param : 14)
  end

  def get_addons_attributes
    {
      enabled_calendar: get_addon_value('1'),
      surveys_enabled: get_addon_value('2'),
      enabled_time_off: get_addon_value('3'),
      enabled_org_chart: get_addon_value('4'),
      enable_custom_table_approval_engine: get_addon_value('5')
    }
  end

  def get_addon_value(value)
    is_addon_enabled = params['a'].include?(value) rescue true
    is_addon_enabled = (is_addon_enabled || get_company_plan == 0) if Integer(value) > 3
    is_addon_enabled
  end

  def create_salesforce_lead
    WebhookServices::SalesforceService.new(salesforce_params, @company).trigger if create_lead?
  end

  def salesforce_params
    params.slice(:first_name, :last_name, :email, :name)
  end

  def start_company_clone
    SandboxAutomation::CompanyAssetsCreationJob.perform_async(get_clone_params) if allow_clone
  end

  def allow_clone
    clone_from = Integer(params['cid']) rescue nil
    case ENV['FRONTEND_MAPPING_SERVER_NAME'] 
    when 'production'
      clone_from == 501
    when 'sandbox' 
      clone_from == 103
    when 'proto0'
      clone_from == 37
    when 'development'
      clone_from == 1
    end
  end

  def get_clone_params
    {
      id: @company.id,
      company_assets: {
        emails: '1',
        reports: '1',
        documents: '1',
        workflows: '1',
        workspaces: '1',
        user_profiles: '1',
        company_links: '1',
        pending_hires: '1',
        profile_fields: '1',
        company_branding: '1',
        platform_settings: '1',
        copy_from: params['cid'],
        time_off: (get_addon_value('3') ? '1' : nil)
      }
    }
  end

  def create_lead?
    Rails.env.production? && (params['sfl'].blank? or params['sfl'] == 'true')
  end

  def is_super_user
    params['su'] == 'true'
  end

  def creat_default_dept_location
    @company.teams.create!(name: "People Operations")
    @company.locations.create!(name: "United States")
  end

  def company_logs_params
    company_params.merge({
      salesforce_cloning: create_lead?,
      trial_end_date: get_trial_period_end,
      clone_id: (allow_clone ? params['cid'] : nil)
    })
  end
end
