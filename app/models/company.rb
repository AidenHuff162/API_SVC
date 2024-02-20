class Company < ActiveRecord::Base
  include CustomTableManagement, IntegrationManagement, VisualizationData, InitializeCompanyPrefrences, TurnoverData, AASM, GoogleCredentialStore, LoggingManagement, InvitationEmailTemplate, CreateDefaultCompanyData
  acts_as_paranoid
  has_paper_trail

  attr_accessor :created_via_signup_page

  belongs_to :owner, class_name: 'User'
  belongs_to :operation_contact, class_name: 'User'
  belongs_to :organization_root, class_name: 'User'
  has_one :salesforce_account, dependent: :nullify
  has_one :super_user, -> { where(super_user: true) }, class_name: 'User'

  before_destroy :nullify_belongings, :destroy_associated_data

  with_options dependent: :destroy do
    has_many :teams
    has_many :company_values, -> { includes :company_value_image }
    has_many :milestones, -> { includes :milestone_image }
    has_many :documents
    has_many :paperwork_templates, -> { where state: 'saved'}
    has_many :paperwork_requests, through: :documents
    has_many :integrations
    has_many :adp_us_integration,  -> { where(api_identifier: 'adp_wfn_us', state: :active) }, class_name: 'IntegrationInstance', foreign_key: :company_id
    has_many :adp_can_integration,  -> { where(api_identifier: 'adp_wfn_can', state: :active) }, class_name: 'IntegrationInstance', foreign_key: :company_id
    has_many :document_upload_requests
    has_many :document_connection_relations, through: :document_upload_requests
    has_many :user_document_connections, through: :document_connection_relations
    has_many :email_templates
    has_many :profile_templates
    has_many :histories
    has_many :job_titles
    has_many :loggings
    has_many :user_roles
    has_many :calendar_feeds
    has_many :comments
    has_many :calendar_events
    has_many :reports
    has_many :pto_policies
    has_many :holidays
    has_many :api_loggings
    has_many :custom_email_alerts
    has_many :paperwork_packets
    has_many :api_keys
    has_many :process_types
    has_many :request_informations
    has_many :monthly_active_user_histories
    has_many :surveys
    has_many :sftps
    has_many :webhooks
    has_many :webhook_events
    has_many :hellosign_calls
    has_one :smart_assignment_configuration
    has_one :billing
    with_options as: :entity do |record|
      record.has_one :display_logo_image, class_name: 'UploadedFile::DisplayLogoImage'
      record.has_one :landing_page_image, class_name: 'UploadedFile::LandingPageImage'
      record.has_many :gallery_images, class_name: 'UploadedFile::GalleryImage'
    end
  end

  before_validation :trim_spaces, if: Proc.new { |c| c.will_save_change_to_subdomain? }
  validates_format_of :name, :buddy, :subdomain, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates :subdomain, exclusion: { in: %w(www try)}
  has_one :paylocity_integration, -> { where(api_name: 'paylocity') }, class_name: 'Integration', foreign_key: :company_id, dependent: :destroy
  has_one :general_data_protection_regulation, dependent: :destroy
  has_many :users
  has_many :active_users, -> { where(state: "active") }, class_name: 'User', foreign_key: :company_id
  has_many :users_without_super_user, -> { where(super_user: false) }, class_name: 'User', foreign_key: :company_id
  has_many :workspaces
  has_many :workstreams
  has_many :locations
  has_many :custom_tables
  has_many :custom_sections, dependent: :nullify
  has_many :custom_fields, -> { where(deleted_at: nil) }
  has_one :employment_field, -> { where(field_type: :employment_status) }, class_name: 'CustomField'

  has_many :pending_hires, dependent: :destroy
  has_many :company_links, dependent: :destroy
  has_many :company_emails, dependent: :destroy
  has_one :google_credential, as: :credentialable, dependent: :destroy
  has_one :organization_chart
  has_many :integration_instances, dependent: :destroy
  has_many :integration_field_mappings, dependent: :destroy
  has_many :general_api_keys, -> { where(api_key_type: ApiKey.api_key_types[:general]) }, class_name: 'ApiKey', foreign_key: :company_id

  accepts_nested_attributes_for :milestones, :company_values, :gallery_images, :company_links, allow_destroy: true
  accepts_nested_attributes_for :adp_us_integration, :adp_can_integration

  after_save :manage_two_factor_authentication, if: Proc.new { |c| c.saved_change_to_otp_required_for_login? }
  before_create :initialize_company_prefrencess
  before_create :initialize_about_section
  before_create :generate_webhook_token
  before_create :set_brand_color
  after_create :create_default_custom_sections
  after_create :create_process_types
  after_create :initialize_role_types
  after_create :set_welcome_note
  after_create :set_preboarding
  after_create :create_standard_custom_fields
  after_create :create_default_admin_role
  after_create :create_default_email_templates
  after_create :create_uuid
  after_create { create_default_custom_tables(self)  if self.is_using_custom_table.present?}
  after_create :set_company_prefrences_custom_section
  # after_create :create_launch_darkly_customer
  after_create :create_custom_workstream
  after_create :create_calendar_permissions
  after_create :create_algolia_index, if: Proc.new{ |c| c.id == 1 }
  after_create :create_default_surveys
  after_update :clear_cache_for_team_and_location, if: :saved_change_to_display_name_format?
  after_update :update_calendar_events, if: :saved_change_to_enabled_calendar?
  after_update :update_users_on_algolia, if: Proc.new { |c| c.saved_change_to_account_state? && c.active?}
  after_update :set_time_off_permissions, if: Proc.new { |c| c.saved_change_to_enabled_time_off? && c.enabled_time_off == true}
  after_update :disable_time_off_custom_alerts, if: Proc.new { |c| c.saved_change_to_enabled_time_off? && c.enabled_time_off == false}
  after_update :remove_empty_hire_manager_forms, if: Proc.new { |c| c.saved_change_to_prefrences? && !c.prefrences['default_fields'].select { |prefrence| prefrence['collect_from'] == 'manager' }.present? }
  # Integration change operations
  after_update :update_groups_from_integration, if: Proc.new { |c| c.saved_change_to_department_mapping_key? || c.saved_change_to_location_mapping_key? }
  after_update :update_department_in_prefrences, if: Proc.new { |c| c.saved_change_to_department? }
  after_update :update_buddy_in_prefrences, if: Proc.new { |c| c.saved_change_to_buddy? }
  after_update :unset_shareable_url, if: Proc.new {|c| c.saved_change_to_enabled_org_chart? && c.token.present?}
  after_update :add_palocity_id_preference_field, if: Proc.new {|c| c.paylocity_integration_type.present? && c.saved_change_to_paylocity_integration_type?}
  after_update :reschedule_weekly_metric_emails, if: Proc.new { |c| c.saved_change_to_time_zone? && c.metrics_email_job_id.present? }
  after_update :delete_profile_template_default_fields, if: :is_default_prefrences_changed?
  after_update :run_create_organization_chart_job, if: Proc.new { |c| c.saved_change_to_organization_root_id? || (c.saved_change_to_enabled_org_chart? && c.enabled_org_chart) || c.saved_change_to_display_name_format?}
  after_create :create_super_user
  after_create :create_default_smart_assignment_configuration
  after_create :create_default_profile_template, if: Proc.new { |c| c.created_via_signup_page }

  scope :active_companies, -> { where(account_state: :active) }

  enum login_type: { only_password: 0, password_and_sso: 1, only_sso: 2 }
  enum overdue_notification: { daily: 0, mondays_wednesdays_and_fridays: 1, tuesdays_and_thursdays: 2, weekly_on_mondays: 3, never: 4 }
  enum integration_type: { no_integration: 0, namely: 1, bamboo: 2, paylocity: 3, adp_wfn_us: 4, adp_wfn_profile_creation_and_bamboo_two_way_sync: 5, adp_wfn_can: 4 }
  enum authentication_type: { google_sso: 0, okta: 1, one_login: 2, active_directory_federation_services: 3, password_only: 4, shibboleth: 5, ping_id: 6}
  enum hiring_type: { Onboarding: 0, HRIS: 1}
  enum date_format: { 'MM/dd/yyyy' => 'mm/dd/yyyy', 'dd/MM/yyyy' => 'dd/mm/yyyy', 'yyyy/MM/dd' => 'yyyy/mm/dd', 'MMM DD, YYYY' => 'MMM DD, YYYY'}
  enum account_type: { production: 0, test: 1, demo: 2, sandbox: 3, trial: 6, implementation: 7 }
  enum company_plan: { people_operations: 0, onboarding: 1}
  enum migration_status: { in_progress: 0, completed: 1 }

  attr_encrypted_options.merge!(:encode => true)
  attr_encrypted :webhook_token, key: ENV['ENCRYPTION_KEY'], algorithm: ENV['ENCRYPTION_ALGORITHM']

  aasm(:state, column: :account_state, whiny_transitions: false) do
    state :active, initial: true
    state :inactive, :cancelled, :delinquent

    event :activate do
      transitions from: :inactive, to: :active
    end

    event :deactivate do
      transitions from: :active, to: :inactive
    end

    event :cancel do
      transitions to: :cancelled
    end

    event :late_payment do
      transitions to: :delinquent
    end
  end

  GROUPED_PREFERENCES_FIELDS = ['loc', 'dpt']
  ALL_PREFERENCES_FIELDS = ["ui", "pp", "fn", "ln", "pn", "ce", "pe", "sd", "ap", "bdy", "abt", "lin", "twt", "gh", "dpt", "jt", "loc", "man", "st", "td", "ltw", "tt", "efr"]
  HELLOSIGN_TEST_MODE_ENABLED = 0
  HELLOSIGN_TEST_MODE_DISABLED = 1

  def set_brand_color
    self.brand_color = '#1a1a33'
  end

  def manage_two_factor_authentication
    ::Users::ManageTfaJob.perform_later(self.id)
  end

  def read_and_store_credentials_in_db(credential)
    read_and_store_google_credentials(credential)
  end

  def reschedule_weekly_metric_emails
    time = Time.now.in_time_zone(self.time_zone)

    if time.saturday? || time.sunday?
      datetime = (time.to_date.at_end_of_week + 1.day).in_time_zone(self.time_zone) + 8.hours
      Sidekiq::ScheduledSet.new.find_job(self.metrics_email_job_id).reschedule(datetime)
    end
  end

  def ats_integration_types
    ats_integrations = self.integrations.where(api_name: ["lever"]).pluck(:api_name) + self.integration_instances.where(api_identifier: ['lever', 'jazz_hr', 'fountain', 'breezy', 'hire_bridge', 'green_house', 'smart_recruiters', 'workable', 'linked_in']).pluck(:api_identifier)
    ats_integrations.uniq
  end

  def ats_integration_type
    Rails.cache.fetch("#{self.id}/ats_integration_type", expires_in: 8.hours) do
      ats_integration = self.integrations.where(api_name: ["lever", "green_house", "smart_recruiters", "workable", "jazz_hr", "linked_in", "breezy", 'hire_bridge']).first
      if !ats_integration
        return "no_ats_integration"
      elsif ats_integration.api_name == "green_house"
        return "greenhouse"
      else
        ats_integration.api_name
      end
    end
  end

  def pm_integration_type(api_name)
    pm_integration_type = self.integration_instances.where(api_identifier: api_name).first
    if pm_integration_type.blank?
      return 'no_pm_integration'
    else
      pm_integration_type.api_identifier
    end
  end

  def pm_integration_path(api_name)
    subdomain = self.integration_instances.where(api_identifier: api_name)&.take&.subdomain
    return unless subdomain.present? || api_name == 'peakon'

    case api_name
    when 'fifteen_five'
      return "https://#{subdomain}.15five.com/profile/engagement/"
    when 'peakon'
      return "https://app.peakon.com/employees/"
    when 'lattice'
      return "https://#{subdomain}.latticehq.com/admin/people/employees/"
    end
  end

  def show_performance_tab
    return true if Rails.env.development?
    feature_flag('sapling-performance-tab')
  end

  def provisioning_integration_type
      productivity_integration = self.integration_instances.where(api_identifier: ["gsuite", "adfs_productivity"], state: :active).first
      if !productivity_integration
        return "no_ats_integration"
      else
        productivity_integration.api_identifier
      end
  end

  def provisioning_integration
    self.integration_instances.find_by_api_identifier(self.provisioning_integration_type)
  end

  def provisioning_integration_url
    case self.provisioning_integration_type
    when 'gsuite'
      return self.provisioning_integration&.gsuite_account_url
    when 'adfs_productivity'
      return self.provisioning_integration&.subdomain
    end
  end

  def integration_types
    self.integration_instances.where(state: :active).pluck(:api_identifier)
  end

  def integration_type
    # Rails.cache.fetch("#{self.id}/integration_type", expires_in: 8.hours) do
      integrations = self.integration_instances.where(state: :active, api_identifier: ["adp_wfn_us", "bamboo_hr", "paylocity", "workday", "adp_wfn_can", "xero", "paychex", "trinet"]).pluck(:api_identifier)
      if integrations.include?('adp_wfn_us') && integrations.include?("adp_wfn_can") && integrations.include?("bamboo_hr").blank?
        return 'adp_wfn_us_and_can'
      elsif integrations.include?("adp_wfn_us") || integrations.include?("adp_wfn_can")
        if integrations.include?("adp_wfn_us")
          return "adp_wfn_us"
        else
          return "adp_wfn_can"
        end
      elsif integrations.include?("workday")
        return "workday"
      elsif integrations.include?("bamboo_hr")
        return "bamboo"
      elsif integrations.include?("xero")
        return "xero"
      elsif integrations.include?("paychex")
        return "paychex"
      elsif integrations.include?("trinet")
        return "trinet"
      elsif integrations.size > 0
        return integrations.first
      else
        "no_integration"
      end
    # end
  end

  def adp_templates_enabled
    integration_instances.active.where(api_identifier: %w[adp_wfn_us adp_wfn_can]).exists?
  end

  # @return [TrueClass,nil] returns +TrueClass+ when enabled, otherwise +nil+
  def adp_us_company_code_enabled
    self.adp_us_integration&.take&.enable_company_code
  end

  # @return [TrueClass,nil] returns +TrueClass+ when enabled, otherwise +nil+
  def adp_can_company_code_enabled
    self.adp_can_integration&.take&.enable_company_code
  end


  # @return [TrueClass, FalseClass] returns +TrueClass+ if either adp_us_company_code_enabled==true or
  #   adp_can_company_code_enabled==true
  def adp_company_code_enabled
    adp_us_company_code_enabled.present? || adp_can_company_code_enabled.present?
  end

  def app_domain
    if ['test', 'development'].include?(Rails.env)
      "#{self.subdomain}.#{ENV['APP_HOST']}"  #frontend.me:8080
    else
      self.domain
    end
  end

  def authentication_type
      if integration = self.integration_instances.find_by(api_identifier: ["okta", "one_login", "active_directory_federation_services", "shibboleth", "google_auth", "ping_id"])
        if integration.api_identifier == "google_auth" && integration.active?
          return "google_sso"
        elsif integration.api_identifier != "google_auth"
          return integration.api_identifier
        end
      end
      "password_only"
  end

  # @return [TrueClass, FalseClass]
  def can_provision_adfs?
    integration_instances.where(api_identifier: 'adfs_productivity', state: :active).exists?
  end

  def create_algolia_index
    User.reindex!
  end

  def nullify_belongings
    logger.info "Stqrt nullyfing belonging"
    self.update_columns(owner_id: nil, operation_contact_id: nil, organization_root_id: nil,enabled_org_chart: false)
    UploadedFile.where(company_id: self.id, type: "UploadedFile::ProfileImage").find_each(batch_size: 100) do |file|
       file.really_destroy!
    end
    UploadedFile.where(company_id: self.id).destroy_all
    logger.info "After nullyfying......"
  end

  def destroy_dependents

      Integration.where(company_id: self.id).destroy_all
      logger.info "-------Integrations destroyed---------"
      CustomField.where(company_id: self.id).destroy_all

      logger.info "-------CustomField Destroyed---------"

      logger.info "-------------Destroying dependents--------------------"
      self.custom_tables.with_deleted.each { |table| table.really_destroy! }

      logger.info "-------------Custom Tables Destroyed------------------"

      self.locations.with_deleted.each do |location|
        location.really_destroy!
      end

      logger.info "--------------Locations destroyed--------------------"

      self.pending_hires.with_deleted.each do |pending_hire|
        pending_hire.really_destroy!
      end

      logger.info "------------Pending Hires Destroyed------------------"

      self.users.with_deleted.find_each do |user|
        user.tasks.with_deleted.find_each do |task|
          task.task_user_connections.with_deleted.find_each do |tuc|
            tuc.really_destroy!
          end

          task.really_destroy!
        end

        logger.info "-------#{user.full_name} task destroyed---------"

        user.task_user_connections.with_deleted.find_each do |tuc|
          tuc.really_destroy!
        end

        logger.info "-------#{user.full_name} tuc destroyed---------"

        PaperworkRequest.with_deleted.where(co_signer_id: user.id).find_each do |paperwork_request|
          paperwork_request.really_destroy!
        end

        logger.info "---#{user.full_name} paperwork_request destroyed.-----"

        user.really_destroy!
        logger.info "#{user.full_name} Destroyed"
      end

      logger.info "-------All users destroyed-----------"

      self.workstreams.with_deleted.each do |workstream|
        workstream.really_destroy!
      end

      logger.info "------All workstreams destroye-------"

      self.workspaces.with_deleted.each do |workspace|
        workspace.really_destroy!
      end

      logger.info "----All workspaces destroyed---------"

      self.api_keys.destroy_all
      logger.info "--------------API keys destroyed--------------------"
  end


  def destroy_users_and_associated_data
    logger.info  "-------Starting destroy users and associated_data---------"
    users = self.users.with_deleted
    logger.info "Total users cound #{users.count}"
    users.find_each(batch_size: 200) do |user|
      user.tasks.with_deleted.find_each do |task|
        task.task_user_connections.with_deleted.find_each do |tuc|
          tuc.really_destroy!
        end
        task.really_destroy!
      end
      logger.info"-------#{user.full_name} task destroyed---------"
      user.task_user_connections.with_deleted.find_each do |tuc|
        tuc.really_destroy!
      end
      logger.info"-------#{user.full_name} tuc destroyed---------"
      PaperworkRequest.with_deleted.where(co_signer_id: user.id).find_each do |paperwork_request|
        paperwork_request.really_destroy!
      end
      logger.info "---#{user.full_name} paperwork_request destroyed.-----"
      user.really_destroy!
      logger.info "#{user.full_name} Destroyed"
    end
    logger.info "-------All users destroyed-----------"
  end


  def destroy_associated_data
    logger.info  "-------Starting destroy associated data---------"
    self.integrations.destroy_all

    logger.info  "-------Integrations destroyed---------"
    self.custom_tables.with_deleted.find_each do | ct|
      ct.really_destroy!
    end
    logger.info  "-------------Custom Tables Destroyed------------------"
    self.locations.with_deleted.find_each do |location|
      location.really_destroy!
    end
    logger.info  "--------------Locations destroyed--------------------"
    # self.pending_hires.each do |ph|
    #   ph.really_destroy!
    # end
    # logger.info  "------------Pending Hires Destroyed-------"
    self.workstreams.with_deleted.find_each do |workstream|
      workstream.really_destroy!
    end
    logger.info  "------All workstreams destroye-------"
    self.workspaces.with_deleted.destroy_all
    logger.info  "----All workspaces destroyed---------"
    self.api_keys.destroy_all
    logger.info "--------------API keys destroyed--------------------"

    CustomField.where(company_id: self.id).destroy_all
    logger.info "-------CustomField Destroyed---------"

    sleep(15)

    destroy_users_and_associated_data
    logger.info "-------Destroyed all associated data along with user associations---------"
  end

  def digest_email_template(data)
    begin
      content = "<p> #{data[:date_range]}</p><br/><b> Weekly Manager Digest</b><br/> <p> Hi there, <br/> Here is the summary of your team's activity for the upcoming week. We hope it helps you better plan your work week. You can also access your team in Sapling.</p><br/>"
      if data[:starting_pto_team_members].present?
        content = content + "<b>Starting Time off</b></br>"
        content = pto_digest_template(data[:starting_pto_team_members], content)
      end
      if data[:returning_pto_team_members].present?
        content = content + "<b>Returning this week</b></br>"
        content = pto_digest_template(data[:returning_pto_team_members], content)
      end

      if data[:ann_team_members].present?
        content = content + "<b>Milestones</b></br>"
        content = user_digest_template(data[:ann_team_members], content, 'anniversary')
      end
      if data[:bday_team_members].present?
        content = content + "<b>Birthdays</b></br>"
        content = user_digest_template(data[:bday_team_members], content, 'birthday')
      end
      content
    rescue Exception => e
      ''
    end
  end

  def generate_token
    token = SecureRandom.hex(15)
    loop do
      break token unless Company.where(token: token).exists?
    end
    self.update_column(:token, token)
  end

  def intercom_feature_flag
    feature_flag('sapling-intercom')
  end

  def limited_sandbox_access
    feature_flag('limited-sandbox-access')
  end

  def survey_paywall_feature_flag
    feature_flag('survey-paywall')
  end

  def pto_paywall_feature_flag
    feature_flag('pto-paywalls')
  end

  def track_approve_paywall_feature_flag
    feature_flag('module-preview-track-approve')
  end

  def org_paywall_feature_flag
    feature_flag('org-chart-paywalls')
  end

  def ohsa_covid_feature_flag
    feature_flag('ohsa-covid-19')
  end

  def gusto_feature_flag
    feature_flag('gusto-integration')
  end

  def history_feature_flag
    feature_flag('sapling-history')
  end

  def bulk_onboarding_feature_flag
    feature_flag('bulk-onboarding')
  end

  def profile_fields_paywall_feature_flag
    feature_flag('profile-fields-approvals-paywall')
  end

  def feedback_feature_flag
    return true if Rails.env.development?
    feature_flag('sapling-feedback')
  end

  def google_groups_feature_flag
    feature_flag('google-ou-groups')
  end

  def flatfile_access_flag
    feature_flag('flatfile-customer-access')
  end

  def smart_assignment_2_feature_flag
    feature_flag('smart-assignment-2')
  end

  def bulk_rehire_feature_flag
    feature_flag('bulk-rehire')
  end

  def approval_feature_flag
    feature_flag('approval-dashboard')
  end

  def profile_approval_feature_flag
    feature_flag('profile-field-approvals')
  end

  def webhook_feature_flag
    return true
    feature_flag('sapling-webhook')
  end

  def kallidus_v1_feature_flag
    feature_flag('kallidus-v1')
  end

  def beta_integration_feature_flag
    return true
  end

  def one_login_updates_feature_flag
    feature_flag('one-login-updates')
  end

  def smart_tasks_assignments_feature_flag
    feature_flag('smart-tasks-assignments')
  end

  def email_rebranding_feature_flag
    feature_flag('email-rebranding')
  end

  def lever_mapping_feature_flag
    feature_flag('lever-custom-mappings')
  end

  def adp_v2_migration_feature_flag
    feature_flag('adp-v2-migration')
  end

  def promo_relo_mvp_feature_flag
    feature_flag('promo-relo-mvp')
  end

  def zapier_feature_flag
    feature_flag('extend-webhook-zapier')
  end

  def zendesk_admin_feature_flag
    feature_flag('admin-only-support')
  end

  def company_trial_feature_flag
    feature_flag('company_based_trials')
  end

  def sync_template_fields_feature_flag
    feature_flag('sync_template_fields')
  end

  def ui_switcher_feature_flag
    feature_flag('ui-switcher')
  end

  def calendar_feed_syncing_feature_flag
    feature_flag('calendar-feed-syncing')
  end

  def task_assignment_refactor_feature_flag
    feature_flag('task_assignment_refactor')
  end

  def update_ui_switcher_fields(ui_switcher)
    self.users.users_with_new_ui_enabled.update(ui_switcher: ui_switcher)
  end

  def sftp_feature_flag; feature_flag('sftp_feature_flag') end
  def api_data_segmentation_feature_flag; feature_flag('api-data-segmentation') end
  def sync_adp_templates_by_v2; feature_flag('sync-adp-templates-by-v2') end
  def adp_zip_validations_feature_flag; feature_flag('adp-zip-validations') end
  def ids_authentication_feature_flag; feature_flag('ids-authentication') end
  def pto_requests_feature_flag; feature_flag('upload-pto-requests') end

  def working_patterns_feature_flag
    feature_flag('working-patterns')
  end

  def run_create_organization_chart_job
    CreateOrganizationChartJob.perform_in(3.minutes, self.id)
  end

  def run_update_organization_chart_job(user_id, options={calculate_custom_groups: false, calculate_team_and_location: true})
    UpdateOrganizationChartJob.perform_in(3.minutes, user_id, options)
  end

  def create_uuid
    #Dont regenrate this token again USING in S3 URL
    uuid = nil
    loop do
      uuid = SecureRandom.urlsafe_base64(8, false)
      break uuid unless Company.with_deleted.where(uuid: uuid).exists?
    end
    self.update_column(:uuid, uuid)
  end

  def global_display_name(user, display_name_format)
    if display_name_format == 0
      if user.preferred_name
        display_name = user.preferred_name.to_s + ' ' + (user.last_name || '')
      else
        display_name = user.first_name.to_s + ' ' + (user.last_name || '')
      end

    elsif display_name_format == 1
      if user.preferred_name
        display_name = user.preferred_name
      else
        display_name = user.first_name
      end

    elsif display_name_format == 2
      display_name = user.first_name.to_s + ' ' + (user.last_name || '')

    elsif display_name_format == 3
      if user.preferred_name
        display_name = user.first_name.to_s+ ' ' + user.preferred_name.to_s + ' ' + (user.last_name || '')
      else
        display_name = user.first_name.to_s + ' ' + (user.last_name || '')
      end

    elsif display_name_format == 4
      display_name = (user.last_name || '') + ', ' + user.first_name.to_s
    end
  end

  def update_org_chart(user, parent, children)
    if user.id == parent['id']
      display_name = self.global_display_name(user, self.display_name_format)
      sub_tree = {
        id: user.id,
        title: user.title,
        name: display_name,
        managed_users_count: user.managed_users_working.length,
        user_name_initials: "#{user.first_name[0]}#{user.last_name[0]}",
        picture: user.picture,
        collapsed: true
      }
      sub_tree['children'] = parent['children']
      if user.location_id
        sub_tree[:location] = user.location.name
      end
      if user.team_id
        sub_tree[:department] = user.team.name
      end
      if user.custom_field_values.present?
        user_custom_field_values = user.custom_field_values.includes(:custom_field_option, :custom_field).where.not(custom_fields: {integration_group: 0})
        user_custom_field_values.each do |cfv|
          field_name = cfv.custom_field.name
          sub_tree[field_name] = cfv.custom_field_option.option if cfv.custom_field_option.present?
        end
      end
      sub_tree
    else
      parent['children'].each_with_index do |child, ind|
        child = update_org_chart(user, child, child['children'])
        parent['children'][ind] = child
      end
      parent
    end
  end

  def update_organization_tree(user_id, options)
    organization_chart = OrganizationChart.find_by_id(self.organization_chart_id)
    return unless organization_chart && organization_chart.user_ids.include?(user_id)
    array_of_ids_check = organization_chart.user_ids
    org_chart = update_org_chart(self.users.find_by_id(user_id), organization_chart.chart, organization_chart.chart['children'])
    org_chart[:department_names] = self.organization_chart.chart['department_names']
    org_chart[:location_names] = self.organization_chart.chart['location_names']
    org_chart[:custom_group_names] = self.organization_chart.chart['custom_group_names']
    checked_users = self.users.where(id: array_of_ids_check) if options[:calculate_team_and_location] || options[:calculate_custom_groups]

    if options[:calculate_team_and_location]
      org_chart[:department_names] = checked_users.joins(:team).pluck(:name).uniq
      org_chart[:location_names] = checked_users.joins(:location).pluck(:name).uniq
    end
    if options[:calculate_custom_groups]
      custom_groups_names = {}
      custom_field_options = CustomFieldOption.includes(:custom_field_values, :custom_field).where(custom_field_values: {user: checked_users}).where("custom_fields.integration_group != ? AND custom_fields.deleted_at IS NULL", CustomField.integration_groups[:no_integration]).uniq
      custom_field_options.each do |custom_option|
        field_name = custom_option.custom_field.name + "_names"
        custom_groups_names[field_name] = [] if custom_groups_names[field_name].blank?
        custom_groups_names[field_name].push custom_option.option if !custom_groups_names[field_name].include?(custom_option.option)
      end
      org_chart[:custom_group_names] = custom_groups_names
    end
    organization_chart.chart = org_chart
    organization_chart.save
  end

  def build_org_chart(root, array_of_ids_check, custom_groups_names, location_names, department_names)
    display_name = self.global_display_name(root, self.display_name_format)
    managed_users_working = root.managed_users_working.includes(:profile_image, :location, :team)
    sub_tree = {
      id: root.id,
      title: root.title,
      name: display_name,
      managed_users_count: managed_users_working.length,
      user_name_initials: "#{root.first_name[0]}#{root.last_name[0]}",
      display_name_format: self.display_name_format,
      picture: root.picture,
      collapsed: true,
      children: []
    }
    if root.location
      sub_tree[:location] = root.location.name
      location_names.push(sub_tree[:location])
    end
    if root.team
      sub_tree[:department] = root.team.name
      department_names.push(sub_tree[:department])
    end
    if root.custom_field_values.present?
      user_custom_field_values = root.custom_field_values.includes(:custom_field_option, :custom_field).where.not(custom_fields: {integration_group: 0})

      user_custom_field_values.each do |cfv|
        field_name = cfv.custom_field.name
        group_field_name = field_name + "_names"
        custom_option = cfv.custom_field_option
        if custom_option.present?
          if custom_groups_names[field_name].present?
            custom_groups_names[field_name].push custom_option.option if !custom_groups_names[field_name].include?(custom_option.option)
          else
            custom_groups_names[field_name] = []
            custom_groups_names[field_name].push custom_option.option
          end
          sub_tree[field_name] = custom_option.option
        end
      end
    end
    managed_users_working.each do |mu|
      if array_of_ids_check.include?(mu.id)
        return sub_tree
      end
      array_of_ids_check.push(mu.id)
      sub_tree[:children] << self.build_org_chart(mu, array_of_ids_check, custom_groups_names, location_names, department_names)
    end
    sub_tree
  end

  def get_org_chart_shareable_url
    if self.enabled_org_chart && self.token.present?
      "https://#{self.app_domain}/#/orgchart/#{self.token}"
    else
      nil
    end
  end

  def get_cached_custom_tables_count
    Rails.cache.fetch([self.id, 'custom_tables_count'], expires_in: 2.hours) do
      self.custom_tables.count
    end
  end

  def generate_organization_tree (give_response=false)
    array_of_ids_check = []
    org_chart = ""
    custom_groups_names = {}
    location_names = []
    department_names = []
    if self.organization_root
      org_chart = build_org_chart(self.organization_root, array_of_ids_check, custom_groups_names, location_names, department_names)
    end
    array_of_ids_check.push(self.organization_root_id)
    org_chart[:department_names] = department_names.uniq
    org_chart[:location_names] = location_names.uniq
    org_chart[:custom_group_names] = custom_groups_names
    organization_chart = OrganizationChart.where(company_id: self.id).first
    organization_chart = OrganizationChart.new if !organization_chart
    organization_chart.chart = org_chart
    organization_chart.user_ids = array_of_ids_check
    organization_chart.company_id = self.id
    organization_chart.save
    self.update_column(:organization_chart_id, organization_chart.id) unless self.organization_chart_id
    if give_response
      org_chart
    end
  end

  def create_custom_workstream
    workstream = Workstream.new
    workstream.name = "Custom Tasks"
    workstream.company_id = self.id
    workstream.position = 0
    workstream.save
  end

  def create_calendar_permissions
    self.update_column(:calendar_permissions, {anniversary: true, birthday: true})
  end

  def update_department_in_prefrences
    prefrences = self.prefrences
    prefrences["default_fields"].each do |field|
      field["name"] = self.department if field["name"] == self.department_before_last_save
    end
    self.update_column(:prefrences, prefrences)
  end

  def get_date_format
    if date_format == 'MM/dd/yyyy'
      return "%m/%d/%Y"
    elsif date_format == 'dd/MM/yyyy'
      return "%d/%m/%Y"
    elsif date_format == 'MMM DD, YYYY'
      return "%b %d,%Y"
    else
      return "%Y/%m/%d"
    end
  end

  def update_buddy_in_prefrences
    prefrences = self.prefrences
    prefrences["default_fields"].each do |field|
      field["name"] = self.buddy if field["name"] == self.buddy_before_last_save
    end
    self.update_column(:prefrences, prefrences)
  end

  def update_home_group_field
    self.update_column(:group_for_home, self.department)
  end

  def update_groups_from_integration
    if self.integration_types.include?('bamboo_hr')
      ::HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob.perform_later(self)
    end
    if self.is_namely_integrated
      UpdateSaplingCustomGroupsFromNamelyJob.perform_later(self)
    end
  end

  def trim_spaces
    self.subdomain = self.subdomain.try(:strip)
  end

  def email_address
    "#{email}@sapling.com" if email.present?
  end

  def set_welcome_note
    self.welcome_note = I18n.t('notifications.admin.company.welcome_note')
    self.save!
  end

  def set_preboarding
    self.preboarding_title = I18n.t('notifications.admin.company.preboarding_title')
    self.preboarding_note = I18n.t('notifications.admin.company.preboarding_note')
    self.save!
  end

  def email_color
    brand_color.present? ? brand_color : '#1a1a33'
  end

  def logo(domain=nil)
    begin
      if display_logo_image.present? && display_logo_image.file.present?
        path = display_logo_image.file_url :thumb
        if Rails.env == "development"
          "http://#{self.domain}:3000#{path}"
        elsif Rails.env == "test"
          "http://#{self.domain}:3001#{path}"
        else
          path
        end
      else
        default = DisplayLogoImageUploader.new.default_url

        domain ? "#{domain}#{default}" : default
      end

    rescue
      retry
    end
  end

  def domain
    "#{self.subdomain}.#{ENV['DEFAULT_HOST']}"
  end

  def create_default_custom_sections
    sections = [ 'profile', 'personal_info', 'private_info', 'additional_fields']
    sections.each do |section|
      self.custom_sections.find_or_create_by(section: CustomSection.sections[section])
    end
  end

  def set_company_prefrences_custom_section
    custom_section_ids = self.custom_sections.pluck(:section,:id).to_h
    self.prefrences['default_fields'].each do |pref|
      if pref['profile_setup'] == 'profile_fields'
        pref.merge!({'custom_section_id' => custom_section_ids[pref['section']]})
      end
    end
    prefrences = self.prefrences
    self.update_columns(prefrences: prefrences)
  end

  def create_default_email_templates
    # new_buddy email template use when buddy changed to otherone
    unless email_templates.where(email_type: 'new_buddy').exists?
      # 'new_manager_buddy_form'
      default_email_template('new_buddy')
    end
    # new_manager email template use when manager changed to otherone
    unless email_templates.where(email_type: 'new_manager').exists?
      default_email_template('new_manager')
    end

    default_template_meta = { 'location_id' => ['all'], 'team_id' => ['all'], 'employee_type' => ['all'] }

    unless email_templates.where(email_type: 'manager_form').exists?
      et = email_templates.new
      et.email_to = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Account Creator Email">Account Creator Email</span>‌</p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌ -&nbsp;<span>Manager Form Completed</span></p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p><span >Hello,</span></p><p>&nbsp;</p><p><span ><span class="token" contenteditable="false" unselectable="on" data-name="Manager Full Name">Manager Full Name</span></span>‌ <span >has completed the required New Hire Information for <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span></span>‌ <span >who is joining <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span></span>‌<span > on ‌<span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span></span>‌<span >.</span></p><p>&nbsp;</p><p><span >You can see all the information collected</span></p><br/><br/>'
      et.email_type = 'manager_form'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'preboarding').exists?
      et = email_templates.new
      et.email_to = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Manager Email">Manager Email</span>‌</p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌&nbsp;<span">has completed Preboarding</span></p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p><span >Hello,</span></p><p>&nbsp;</p><p><span ><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span></span>‌<span >‌ has completed Preboarding in Sapling, and is all set to join on <span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span></span>‌<span >‌.</span></p><p>&nbsp;</p><ul><li><span >Name: </span><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌</li><li><span >Title: </span><span > </span><span class="token" contenteditable="false" unselectable="on" data-name="Job Title">Job Title</span>‌</li><li><span >Manager: </span><span class="token" contenteditable="false" unselectable="on" data-name="Manager Full Name">Manager Full Name</span>‌</li><li><span >Location: </span><span class="token" contenteditable="false" unselectable="on" data-name="Location">Location</span>‌</li><li><span >Department: </span><span class="token" contenteditable="false" unselectable="on" data-name="Department">Department</span>‌</li><li><span >Start Date: </span><span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span>‌</li></ul><p>&nbsp;</p><p><span >The link below will take you to</span><span > </span><span ><span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span></span>‌&apos;<span >s full Employee Record in Sapling.</span></p><br/><br/>'
      et.email_type = 'preboarding'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'new_activites_assigned').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌&nbsp;<span>Activities to Complete for&nbsp;</span><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p><span >Hey </span><span class="token" contenteditable="false" unselectable="on" data-name="Task Owner First Name">Task Owner First Name</span>‌</p><p>&nbsp;</p><p><span ><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span></span>‌ <span >activities were assigned to you to complete for <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span></span>‌<span >.</span></p><p>&nbsp;</p><p><span ><span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span></span>‌ <span >is joining <span class="token" contenteditable="false" unselectable="on" data-name="Department">Department</span></span>‌ <span >in <span class="token" contenteditable="false" unselectable="on" data-name="Location">Location</span></span>‌ <span >on <span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span></span>‌<span >.</span></p><br/><br/>'
      et.email_type = 'new_activites_assigned'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'new_manager_form').exists?
      et = email_templates.new
      et.email_to = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Manager Email">Manager Email</span>‌</p>'
      et.subject = '<p><span><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span></span>‌<span>‌ - New Hire Information Required</span></p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p><span>Hi </span><span class="token" contenteditable="false" unselectable="on" data-name="Manager First Name">Manager First Name</span>‌</p><p>&nbsp;</p><p><span >The People Operations team requires some information about <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span></span>‌ <span >who is joining <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span></span>‌ <span >on <span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span></span>‌<span >‌.</span></p><p>&nbsp;</p><p><span >Please ensure your complete this information as soon as possible so your People Operations team can get your new hire set-up for success.</span></p><br/><br/>'
      et.email_type = 'new_manager_form'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'document_completion').exists?
      et = email_templates.new
      et.email_to = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Account Creator Email">Account Creator Email</span>‌</p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌‌ Document Complete</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = "<p><span class='token' contenteditable='false' unselectable='on' data-name='Full Name'>Full Name</span> has completed the <span class='token' contenteditable='false' unselectable='on' data-name='Document Name'>Document Name</span>‌ document in Sapling.</p><br/><p>The link below will take you to <span class='token' contenteditable='false' unselectable='on' data-name='Preferred/ First Name'>Preferred/ First Name</span>'s Employee Record in Sapling.</p>"
      et.email_type = 'document_completion'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'onboarding_activity_notification').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌ onboarding tasks to Complete for&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi <span class="token" contenteditable="false" unselectable="on" data-name="Task Owner First Name">Task Owner First Name</span>‌‌,</p><br/><p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌‌ tasks were assigned to you to supp&#111;&#114;t <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌‌’s onboarding for <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>‌‌.</p><br/><p><span class="token" contenteditable="false" unselectable="on" data-name="First Name">First Name</span>‌‌ joins <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>‌‌ on <span class="token" contenteditable="false" unselectable="on" data-name="Start Date">Start Date</span>‌.</p>'
      et.email_type = 'onboarding_activity_notification'
      et.name = 'New Activities - Onboarding'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'transition_activity_notification').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌‌ to complete for <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌&nbsp;(<span class="token" contenteditable="false" unselectable="on" data-name="Department">Department</span>‌, <span class="token" contenteditable="false" unselectable="on" data-name="Location">Location</span>‌) </p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p> Hey <span class="token" contenteditable="false" unselectable="on" data-name="Task Owner First Name">Task Owner First Name</span>‌,</p><br/><p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌‌‌ tasks were assigned to you f&#111;&#114; <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌.</p>'
      et.email_type = 'transition_activity_notification'
      et.name = 'New Activities - Transition'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'offboarding_activity_notification').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌&nbsp;‌offboarding tasks to complete for&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi <span class="token" contenteditable="false" unselectable="on" data-name="Task Owner First Name">Task Owner First Name</span>‌,</p><br/><p><span class="token" contenteditable="false" unselectable="on" data-name="Task Count">Task Count</span>‌ tasks were assigned to you to supp&#111;&#114;t <span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌’s offboarding from <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>‌.</p><br/><p><span class="token" contenteditable="false" unselectable="on" data-name="First Name">First Name</span>‌ leaves <span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>‌ on <span class="token" contenteditable="false" unselectable="on" data-name="Termination Date">Termination Date</span>‌.</p>'
      et.email_type = 'offboarding_activity_notification'
      et.name = 'New Activities - Offboarding'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'new_pending_hire').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p>New Pending Hire in Sapling</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi <span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span>&zwnj;,</p><p><br></p><p>There has been a change in start date for <strong><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>&zwnj;</strong></p><p><br></p><p>The start date has been changed from <span class="token" contenteditable="false" unselectable="on" data-name="Old Start Date">Old Start Date</span> to <strong><span class="token" contenteditable="false" unselectable="on" data-name="Current Start Date">Current Start Date</span></strong>&zwnj;<strong>&zwnj;</strong>.</p>'
      et.email_type = 'new_pending_hire'
      et.name = 'New Pending Hire'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'start_date_change').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p>Start Date Change:&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>‌ (<span class="token" contenteditable="false" unselectable="on" data-name="Location">Location</span>‌)</p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi <span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span>&zwnj;,</p><p><br></p><p>There has been a change in start date for <strong><span class="token" contenteditable="false" unselectable="on" data-name="Full Name">Full Name</span>&zwnj;</strong></p><p><br></p><p>The start date has been changed from <span class="token" contenteditable="false" unselectable="on" data-name="Old Start Date">Old Start Date</span> to <strong><span class="token" contenteditable="false" unselectable="on" data-name="Current Start Date">Current Start Date</span></strong>&zwnj;<strong>&zwnj;</strong>.</p>'
      et.email_type = 'start_date_change'
      et.name = 'Start Date Change'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'invite_user').exists?
      et = email_templates.new
      et.email_to = '<p><br></p>'
      et.subject = '<p><b><span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span> invited to join Sapling!</b></p>'
      et.bcc = '<p><br></p>'
      et.cc = '<p><br></p>'
      et.description = '<p>Hi&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Preferred/ First Name">Preferred/ First Name</span>&zwnj;,</p><p><br></p><p>Your&nbsp;<span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>&nbsp;has invited you to use Sapling.</p><p><br></p><p><span class="token" contenteditable="false" unselectable="on" data-name="Company Name">Company Name</span>&nbsp;uses Sapling to manage both their People data as well as People Operations processes.</p><p></p><p>Please click on the button below to log into Sapling. You will be able to complete any required profile or job information that HR may need from you, submit any required documentation, and check out any tasks that are assigned to you by your People Operations team.</p><p><br></p><p>If you have any questions, please reach out to your People Operations team or check out our <a href="https://www.saplinghr.com/core-pages/help">help center</a>.</p><p><br></p>'
      et.email_type = 'invite_user'
      et.name = 'Invitation to Sapling'
      et.meta = default_template_meta
      et.save
    end

    unless email_templates.where(email_type: 'invitation').exists?
      create_invitation_email_template(self)
    end
    CustomEmailAlertService.new.create_default_custom_alerts(self)
  end

  def create_process_types
    ProcessType.create(name: 'Onboarding', is_default: true, company_id: self.id)
    ProcessType.create(name: 'Offboarding', is_default: true, company_id: self.id)
    ProcessType.create(name: 'Relocation', is_default: true, company_id: self.id)
    ProcessType.create(name: 'Promotion', is_default: true, company_id: self.id)
    ProcessType.create(name: 'Other', is_default: true, company_id: self.id)
  end

  def initialize_role_types
    self.role_types = [
      { name: I18n.t('admin.settings.roles.employees'), position: 0, role_type: 'employee'},
      { name: I18n.t('admin.settings.roles.managers'), position: 1, role_type: 'manager'},
      { name: I18n.t('admin.settings.roles.admins'), position: 2, role_type: 'admin'},
      { name: I18n.t('admin.settings.roles.super_admins'), position: 3, role_type: 'super_admin'},
      { name: 'Temporary Administrators', position: 4, role_type: 'super_admin'}
    ]
    self.save!
  end

  def create_default_admin_role
    UserRole.create!(
      name: 'Ghost Admin',
      permissions: {
        platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'view_and_edit', calendar: 'view_only', time_off: 'view_and_edit', updates: 'view_and_edit', people: 'view_and_edit' },
        employee_record_visibility: { private_info: 'view_and_edit', personal_info: 'view_and_edit', additional_info: 'view_and_edit' },
        admin_visibility: { dashboard: 'view_and_edit', reports: 'view_and_edit', records: 'view_and_edit', documents: 'view_and_edit', tasks: 'view_and_edit', general: 'view_and_edit', groups: 'view_and_edit', emails: 'view_and_edit', integrations: 'view_and_edit', permissions: 'view_and_edit', time_off: 'view_and_edit' }
      },
      company_id: self.id,
      role_type: UserRole.role_types[:super_admin],
      is_default: true
    )

    UserRole.create!(
      name: 'Super Admin',
      permissions: {
        platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'view_and_edit', calendar: 'view_only', time_off: 'view_and_edit', updates: 'view_and_edit', people: 'view_and_edit' },
        employee_record_visibility: { private_info: 'view_and_edit', personal_info: 'view_and_edit', additional_info: 'view_and_edit' },
        admin_visibility: { dashboard: 'view_and_edit', reports: 'view_and_edit', records: 'view_and_edit', documents: 'view_and_edit', tasks: 'view_and_edit', general: 'view_and_edit', groups: 'view_and_edit', emails: 'view_and_edit', integrations: 'view_and_edit', permissions: 'view_and_edit', time_off: 'view_and_edit' }
      },
      company_id: self.id,
      role_type: UserRole.role_types[:super_admin],
      is_default: true
    )

    UserRole.create!(
      name: 'Admin',
      permissions: {
        own_platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'view_and_edit', calendar: 'view_only', time_off: 'view_and_edit', updates: 'view_and_edit', people: 'view_only' },
        platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'view_and_edit', calendar: 'view_only', time_off: 'no_access', updates: 'view_and_edit', people: 'view_and_edit' },
        own_info_visibility: { private_info: 'view_and_edit', personal_info: 'view_and_edit', additional_info: 'view_and_edit' },
        employee_record_visibility: { private_info: 'no_access', personal_info: 'view_and_edit', additional_info: 'view_and_edit' },
        admin_visibility: { dashboard: 'view_and_edit', reports: 'no_access', records: 'no_access', documents: 'view_and_edit', tasks: 'view_and_edit', general: 'view_and_edit', groups: 'view_and_edit', emails: 'view_and_edit', integrations: 'no_access', permissions: 'no_access', time_off: 'view_only' }
      },
      company_id: self.id,
      role_type: UserRole.role_types[:admin],
      is_default: true,
      location_permission_level: ['all'],
      team_permission_level: ['all'],
      status_permission_level: ['all']
    )

    UserRole.create!(
      name: 'Manager',
      permissions: {
        own_platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'no_access', calendar: 'view_only', time_off: 'no_access', updates: 'view_and_edit', people: 'view_only' },
        platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'no_access', calendar: 'view_only', time_off: 'view_only', updates: 'view_and_edit' },
        own_info_visibility: { private_info: 'view_and_edit', personal_info: 'view_and_edit', additional_info: 'view_and_edit' },
        employee_record_visibility: { private_info: 'no_access', personal_info: 'view_and_edit', additional_info: 'view_and_edit' }
      },
      company_id: self.id,
      role_type: UserRole.role_types[:manager],
      is_default: true
    )

    UserRole.create!(
      name: 'Employee',
      permissions: {
        platform_visibility: { profile_info: 'view_and_edit', task: 'view_and_edit', document: 'view_and_edit', calendar: 'view_only', time_off: 'no_access', updates: 'view_and_edit', people: 'view_only' },
        employee_record_visibility: { private_info: 'view_and_edit', personal_info: 'view_and_edit', additional_info: 'view_and_edit' }
      },
      company_id: self.id,
      role_type: UserRole.role_types[:employee],
      is_default: true
    )
  end

  def create_standard_custom_fields
    custom_section_ids = self.custom_sections.pluck(:section,:id).to_h

    home_phone = CustomField.create!(name: "Home Phone Number", company_id: self.id, field_type: 8, section: 0, custom_section_id: custom_section_ids['personal_info'], locks: {all_locks: true}, required: true, position: 10)
    SubCustomField.create!(custom_field_id: home_phone.id, name: 'Country', field_type: 'short_text', help_text: 'Country')
    SubCustomField.create!(custom_field_id: home_phone.id, name: 'Area code', field_type: 'short_text', help_text: 'Area code')
    SubCustomField.create!(custom_field_id: home_phone.id, name: 'Phone', field_type: 'short_text', help_text: 'Phone')

    mobile_phone = CustomField.create!(name: "Mobile Phone Number", company_id: self.id, field_type: 8, section: 0, custom_section_id: custom_section_ids['personal_info'], locks: {all_locks: true}, required: true, position: 11)

    SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Country', field_type: 'short_text', help_text: 'Country')
    SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Area code', field_type: 'short_text', help_text: 'Area code')
    SubCustomField.create!(custom_field_id: mobile_phone.id, name: 'Phone', field_type: 'short_text', help_text: 'Phone')

    CustomField.create!(name: "Food Allergies/Preferences", company_id: self.id, field_type: 0, section: 2, custom_section_id: custom_section_ids['additional_fields'], required: true, position: 0)
    CustomField.create!(name: "Dream Vacation Spot", company_id: self.id, field_type: 0, section: 2, custom_section_id: custom_section_ids['additional_fields'], required: true, position: 1)
    CustomField.create!(name: "Favorite Food", company_id: self.id, field_type: 0, section: 2, custom_section_id: custom_section_ids['additional_fields'], required: true, position: 2)
    CustomField.create!(name: "Pets and Animals", company_id: self.id, field_type: 0, section: 2, custom_section_id: custom_section_ids['additional_fields'], required: true, position: 3)
    shirt_size = CustomField.create!(name: "T-Shirt Size", company_id: self.id, field_type: 4, section: 2, custom_section_id: custom_section_ids['additional_fields'], required: true, position: 4)
    CustomFieldOption.create!(custom_field_id: shirt_size.id, option: "Small")
    CustomFieldOption.create!(custom_field_id: shirt_size.id, option: "Medium")
    CustomFieldOption.create!(custom_field_id: shirt_size.id, option: "Large")
    CustomFieldOption.create!(custom_field_id: shirt_size.id, option: "X-Large")

    CustomField.create!(name: "Social Security Number", company_id: self.id, field_type: 5, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 0)
    marital_status = CustomField.create!(name: "Federal Marital Status", company_id: self.id, field_type: 4, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 1)
    CustomFieldOption.create!(custom_field_id: marital_status.id, option: "Single")
    CustomFieldOption.create!(custom_field_id: marital_status.id, option: "Married filing jointly")
    CustomFieldOption.create!(custom_field_id: marital_status.id, option: "Married filing separately")
    CustomFieldOption.create!(custom_field_id: marital_status.id, option: "Head of household")
    CustomFieldOption.create!(custom_field_id: marital_status.id, option: "Qualifying widow(er) with dependent child")

    CustomField.create!(name: "Date of Birth", company_id: self.id, field_type: 6, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 2)
    home_address = CustomField.create!(name: "Home Address", company_id: self.id, field_type: 7, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 3)
    SubCustomField.create!(custom_field_id: home_address.id, name: 'Line 1', field_type: 'short_text', help_text: 'Line 1')
    SubCustomField.create!(custom_field_id: home_address.id, name: 'Line 2', field_type: 'short_text', help_text: 'Line 2')
    SubCustomField.create!(custom_field_id: home_address.id, name: 'City', field_type: 'short_text', help_text: 'City')
    SubCustomField.create!(custom_field_id: home_address.id, name: 'Country', field_type: 'short_text', help_text: 'Country')
    SubCustomField.create!(custom_field_id: home_address.id, name: 'State', field_type: 'short_text', help_text: 'State')
    SubCustomField.create!(custom_field_id: home_address.id, name: 'Zip', field_type: 'short_text', help_text: 'Zip/ Post Code')

    gender = CustomField.create!(name: "Gender", company_id: self.id, field_type: 4, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 4, locks: { all_locks: true, options_lock: false })
    CustomFieldOption.create!(custom_field_id: gender.id, option: "Male")
    CustomFieldOption.create!(custom_field_id: gender.id, option: "Female")
    CustomFieldOption.create!(custom_field_id: gender.id, option: "Other")
    CustomFieldOption.create!(custom_field_id: gender.id, option: "Not specified")

    ethnicity = CustomField.create!(name: "Race/Ethnicity", company_id: self.id, field_type: 4, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 5, locks: { all_locks: true, options_lock: false })
    CustomFieldOption.create!(custom_field_id: ethnicity.id, option: "Asian")

    CustomField.create!(name: "Emergency Contact Name", company_id: self.id, field_type: 0, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 6)
    emergency_relationship = CustomField.create!(name: "Emergency Contact Relationship", company_id: self.id, field_type: 4, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 7)

    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Wife", position: 1)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Husband", position: 2)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Mother", position: 3)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Father", position: 4)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Sister", position: 5)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Brother", position: 6)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Daughter", position: 7)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Son", position: 8)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Friend", position: 9)
    CustomFieldOption.create!(custom_field_id: emergency_relationship.id, option: "Other", position: 10)

    emergency_contact = CustomField.create!(name: "Emergency Contact Number", company_id: self.id, field_type: 8, section: 4, custom_section_id: custom_section_ids['private_info'], required: true, position: 8)
    SubCustomField.create!(custom_field_id: emergency_contact.id, name: 'Country', field_type: 'short_text', help_text: 'Country')
    SubCustomField.create!(custom_field_id: emergency_contact.id, name: 'Area code', field_type: 'short_text', help_text: 'Area code')
    SubCustomField.create!(custom_field_id: emergency_contact.id, name: 'Phone', field_type: 'short_text', help_text: 'Phone')

    employment_status = CustomField.create!(name: 'Employment Status', company_id: self.id, field_type: CustomField.field_types[:employment_status], position: 9, section: 0, custom_section_id: custom_section_ids['personal_info'], locks: { all_locks: false, options_lock: false },required: false, collect_from: :admin, integration_group: 6)
    if employment_status
      employment_status.custom_field_options.create!(option: 'Full Time', position: 0)
      employment_status.custom_field_options.create!(option: 'Part Time', position: 1)
    end
  end

  def delete_profile_template_default_fields
    ids = self.prefrences['default_fields']&.pluck('id')
    ProfileTemplateCustomFieldConnection.joins(:profile_template).where({ profile_templates: { company_id: self }})
                                                                 .where.not(default_field_id: ids)&.destroy_all
  end

  def remove_empty_hire_manager_forms
    if self.custom_fields.where(collect_from: 2).count == 0 && !self.prefrences['default_fields'].select { |prefrence| prefrence['collect_from'] == 'manager' }.present?
      users = self.users.where(is_form_completed_by_manager: User.is_form_completed_by_managers[:incompleted])
      users.try(:each) do |user|
        user.is_form_completed_by_manager = User.is_form_completed_by_managers[:no_fields]
        user.save
      end
    end
  end

  def get_saml_sso_target_url
    self.integration_instances.find_by(api_identifier: self.authentication_type, state: :active).identity_provider_sso_url rescue nil
  end

  def get_saml_idp_cert
    self.integration_instances.find_by(api_identifier: self.authentication_type, state: :active).saml_certificate rescue nil
  end

  def get_group_names(company_id)
    groups = [self.department]
    groups += CustomField.joins(:company).where("companies.id = ? AND custom_fields.integration_group > ?", company_id, CustomField.integration_groups[:no_integration]).where(deleted_at: nil).pluck(:name)
  end

  def get_gsuite_account_info
    return self.integration_instances.find_by(api_identifier: 'gsuite', state: :active)
  end

  def find_new_gsuite_id_for_user current_user
    gsuite_ids = self.users.all.pluck(:email).compact
    compnay_gsuite_url = self.get_gsuite_account_info.gsuite_account_url
    user_id_initials = "#{current_user.first_name.downcase}#{current_user.last_name.downcase}"
    current_users_id = "#{user_id_initials}@#{compnay_gsuite_url}"
    while gsuite_ids.include?("#{current_users_id}") do
      current_users_id = "#{user_id_initials}#{rand(1..9999)}@#{compnay_gsuite_url}"
    end

    current_users_id
  end

  def gsuite_credentials_present_for_company
    gsuite_integraion = self.get_gsuite_account_info
    self.enable_gsuite_integration && gsuite_integraion.present? && gsuite_integraion.gsuite_account_url.present?
  end

  def self.create_launchdarkly_users_for_existing_companies
    if Rails.application.config.ld_client.present?
      Company.all.each do |company|
        Rails.application.config.ld_client.identify(create_ld_user_context(company.name, false))
        Rails.application.config.ld_client.flush
      end
    else
      puts '!!!!*** Launch Darkly client uninitialized or not found !!!!***'
    end
  end

  def create_launch_darkly_customer
    if Rails.application.config.ld_client.present?
      Rails.application.config.ld_client.identify(create_ld_user_context(name, false))
    else
      create_general_logging(self, 'Creating new user on after create', { failure: 'Launch Darkly client uninitialized or not found' })
    end
  end

  def team_validity event, user
    event.team_permission_level.include?(user.team_id.to_s) or event.team_permission_level.include?('all')
  end

  def location_validity event, user
    event.location_permission_level.include?(user.location_id.to_s) or event.location_permission_level.include?('all')
  end

  def status_validity event, user
    event.status_permission_level.include?(user.employee_type) or event.status_permission_level.include?('all')
  end

  def singular_department
    self.department.singularize
  end

  def date_validation event, date_arr
    overlapping = (event.begin_date..event.end_date).to_a & date_arr
    return false if overlapping.count == 0
    return true
  end

  def get_holidays_between_dates begin_date, end_date, user
    date_arr = (begin_date..end_date).to_a
    holiday_dates = []
    holidays = []
    comp_holidays = self.holidays.select {|event| team_validity(event, user) and (location_validity(event, user)) and (status_validity(event, user)) and (date_validation(event, date_arr))}

    comp_holidays.each do |holiday|
      holiday.end_date = holiday.begin_date if !holiday.multiple_dates
      date_range = holiday.begin_date, holiday.end_date
      holidays.push date_range
    end

    if holidays.present?
      holiday_dates = holidays.map{|holiday| (holiday[0].to_date..holiday[1].to_date).to_a}.flatten.uniq
    end
    holiday_dates
  end

  def get_object_name
    self.name
  end

  def get_type_name(type)
    if type == 'new_buddy'
      'buddy'
    elsif type == 'new_manager'
      'manager'
    end
  end

  def get_token_name(type)
    if type == 'new_buddy'
      "#{self.buddy} First Name"
    elsif type == 'new_manager'
      'Manager First Name'
    end
  end

  def get_manager_buddy_default_subject(type)
    "<p>You've been assigned as #{get_type_name(type)} for&nbsp;<span class='token' contenteditable='false' unselectable='on' data-name='Full Name'>Full Name</span>‌.</p>"
  end

  def get_manager_buddy_default_description(type)
    "<p>Congratulations <span class='token' contenteditable='false' unselectable='on' data-name='#{get_token_name(type)}'>#{get_token_name(type)}</span>‌! You’re about to make a new friend!</p><p><br></p><p><span class='token' contenteditable='false' unselectable='on' data-name='Hire Full Name'>Hire Full Name</span> is joining us in <span class='token' contenteditable='false' unselectable='on' data-name='Hire Location'>Hire Location</span> on <span class='token' contenteditable='false' unselectable='on' data-name='Hire Start Date'>Hire Start Date</span>‌ and you’re their #{get_type_name(type)}. You’re going to be an important part of <span class='token' contenteditable='false' unselectable='on' data-name='Hire First Name'>Hire First Name</span>‌’s success here at <span class='token' contenteditable='false' unselectable='on' data-name='Company Name'>Company Name</span>.</p><p><br></p><p>Login to Sapling to learn more. </p>"
  end

  def default_email_template(type)
    et = self.email_templates.new
    et.email_to = '<p><br></p>'
    et.subject = self.get_manager_buddy_default_subject(type)
    et.bcc = '<p><br></p>'
    et.cc = '<p><br></p>'
    et.description = self.get_manager_buddy_default_description(type)
    et.email_type = type
    et.meta = {"location_id" => ["all"], "team_id" => ["all"], "employee_type" => ["all"]}
    et.save
  end

  def update_email_template_by_type(type)
    email_templates = self.email_templates.find_by_email_type(type)
    return if email_templates.blank?
    email_templates.update_column(:subject, self.get_manager_buddy_default_subject(type))
    email_templates.update_column(:description, self.get_manager_buddy_default_description(type))
  end

  def update_manager_buddy_email_template
    self.update_email_template_by_type('new_manager')
    self.update_email_template_by_type('new_buddy')
  end

  def is_jira_enabled
    Rails.cache.fetch("#{self.id}/jira_integration", expires_in: 2.days) do
      jira = self.integrations.find_by(api_name: "jira") rescue nil
      jira && jira.secret_token.present? && jira.jira_complete_status.present? rescue nil
    end
  end

  def is_service_now_enabled?
    self.integration_instances.where(api_identifier: 'service_now', state: "active" ).any? rescue false
  end

  def is_namely_integrated
    self.integration_instances.where(api_identifier: 'namely', state: "active" ).any? rescue false
  end

  def is_xero_integrated?
     return self.integration_instances.where(api_identifier: 'xero').any?
  end

  # @return [TrueClass, FalseClass]
  def asana_integration_enabled
    integration_instances.where(api_identifier: 'asana').exists?
  end

  def gsuite_account_exists
    gsuite_account = self.get_gsuite_account_info rescue nil
    gsuite_account.present? && gsuite_account.gsuite_account_url.present? rescue nil
  end

  def provisiong_account_exists?
    provisiong_account_present = false
    if self.provisioning_integration.present?
      case self.provisioning_integration.api_identifier
      when "gsuite"
        provisiong_account_present = self.gsuite_credentials_present_for_company
      when "adfs_productivity"
        provisiong_account_present = can_provision_adfs?
      end
    end

    return provisiong_account_present
  end

  def link_gsuite_personal_email
    gsuite_account = self.get_gsuite_account_info rescue nil
    gsuite_account.present? && gsuite_account.link_gsuite_personal_email.present? rescue nil
  end

  def teams_and_locations
    Rails.cache.fetch("#{self.id}/teams_and_locations", expires_in: 2.days) do
      ActiveModelSerializers::SerializableResource.new(self ,serializer: CompanySerializer::TeamsAndLocations)
    end
  end

  def clear_cache_for_team_and_location
    Rails.cache.delete("#{self.id}/teams_and_locations")
    return true
  end

  def pto_events
    if self.enabled_time_off
      policies = self.pto_policies.enabled.pluck(:policy_type).uniq
      if policies.present?
        events = PtoPolicy.policy_types.select { |k, v| policies.include? k}.keys.map(&:titleize)

        if events.include? 'Vacation'
          index = events.index('Vacation')
          events[index] = 'Paid Time Off'
        end

        if events.include? 'Sick'
          index = events.index('Sick')
          events[index] = 'Sick Leave'
        end

        return events
      end
    end

    []
  end

  def show_adfs_link
    begin
      integration = self.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active)
      self.authentication_type == 'active_directory_federation_services' and integration.present? and integration.saml_certificate.present? and integration.identity_provider_sso_url.present?
    rescue Exception => e
    end
  end

  def show_saml_login_button
    begin
      saml_obj = nil
      auth_type = self.authentication_type
      if auth_type == 'google_sso'
        auth_obj = self.integration_instances.find_by(api_identifier: 'google_auth', state: :active)
      else
        auth_obj = self.integration_instances.find_by(api_identifier: auth_type, state: :active)
      end
      presence = auth_obj.present? && (((auth_type == 'okta' || auth_type == 'one_login' || auth_type == 'shibboleth' || auth_type == 'ping_id') && auth_obj.saml_certificate.present? && auth_obj.identity_provider_sso_url.present?) || (auth_type == 'google_sso' && auth_obj.active?))
      if auth_type == 'shibboleth'
        presence = false if check_if_shib_attributes_exist?
      end
      {integration_type: auth_type, presence: presence}
    rescue Exception => e
    end
  end

  def time
    Time.now.in_time_zone(self.time_zone)
  end

  def get_visualization_data params
    self.calculate_custom_date_headcounts(params)
  end

  def get_turnover_data params
    self.calculate_custom_date_turnovers(params)
  end

  def self.all_companies_alphabeticaly
     self.order("lower(companies.name) ASC").all
  end

  def error_notification_emails= emails
    if emails.is_a? String
      super emails.split(",").map(&:strip)
    else
      super emails
    end
  end

  def managers
    self.users.pluck(:manager_id).uniq.compact
  end

  def active_managers
    self.users.where(id: managers).where.not("users.current_stage IN (?)", [User.current_stages[:incomplete], User.current_stages[:departed]]).where(state: 'active').pluck(:id).uniq.compact
  end

  def directory_managers
    self.users.where("users.start_date <= ?", Date.today).where(super_user: false, state: :active, current_stage: [3, 4, 5, 6, 11, 13, 14]).pluck(:manager_id).uniq.compact
  end

  def destroy_by_job
    DeleteCompany.perform_later(self.id)
  end


  def fetch_offboarding_user
    self.users.where.not(current_stage: User.current_stages[:departed], termination_date: nil).where("last_offboarding_event_date IS NULL OR last_offboarding_event_date != ?", Time.now.utc.to_date)
  end

  def fetch_removed_access_user
    self.users.where("((users.current_stage != ? AND users.termination_date IS NOT NULL) AND (last_offboarding_event_date IS NULL OR last_offboarding_event_date != ?)) OR (users.termination_date IS NOT NULL AND users.remove_access_state = ? AND users.current_stage = ?)",User.current_stages[:departed], Time.now.utc.to_date, User.remove_access_states[:pending], User.current_stages[:departed])
  end

  def self.current
    RequestStore.store[:company]
  end

  def self.current=(company)
    RequestStore.store[:company] = company
  end

  def self.clear_current_company
    RequestStore.clear!
  end

  def create_super_user
    unless Rails.env.test?
      superuser = self.users.create!({
        first_name: 'Super',
        last_name: 'User',
        email: 'super_user@'+self.domain,
        password: ENV['USER_PASSWORD'],
        personal_email: 'super_user.personal@'+self.domain,
        title: 'Super User',
        role: :account_owner,
        state: :active,
        current_stage: :registered,
        start_date: 31.days.ago
        })

      superuser.create_profile!
    end
  end

  def update_users_on_algolia
    self.users.algolia_reindex unless ['test', 'development'].include?(Rails.env)
  end

  def create_default_surveys
    Survey.create_default_surveys(self)
  end

  def revoke_token
    token = "#{SecureRandom.hex(15)}#{self.id}#{Time.now.to_i}"
    self.update(webhook_token: token)
    token
  end

  def get_default_prefrences_field_names(api_field_ids)
    self.prefrences['default_fields'].map { |field| field['name'] if api_field_ids.include?(field['api_field_id']) }.reject(&:nil?)
  end

  def get_date_regex

    case self.date_format
    when "MM/dd/yyyy"
      return '%m/%d/%Y'
    when "MMM DD, YYYY"
      return '%b %d, %Y'
    when "dd/MM/yyyy"
      return '%d/%m/%Y'
    when "yyyy/MM/dd"
      return '%Y/%m/%d'
    end
  end

  def pending_hire_flatfile_access_flag
    return true if Rails.env.staging?
    feature_flag('pending-hire-flatfile-customer-access')
  end

  def update_preboarding_document(include_documents)
    self.update(include_documents_preboarding: include_documents)
  end

  def active_integration_names
    exclude_integrations = ['learn_upon', 'lessonly', 'gusto', 'lattice', 'paychex', 'deputy', 'fifteen_five', 'peakon', 'trinet', 'paylocity', 'namely', nil]
    (integrations.enabled(exclude_integrations).pluck(:api_name) | integration_instances.enabled.pluck(:api_identifier))
  end

  def get_custom_fields_for_mapping(inventory_field_mapping_option)
    return [] unless inventory_field_mapping_option.present?

    case inventory_field_mapping_option
    when 'custom_groups'
      self.custom_fields.grouped_custom_fields('no_integration')
    when 'all_fields'
      self.custom_fields
    end
  end

  def default_field_prefrences_for_mapping(inventory_field_mapping_option)
    return [] unless inventory_field_mapping_option.present?
    prefrences = []
    included_fields = []

    case inventory_field_mapping_option
    when 'custom_groups'
      included_fields = Company::GROUPED_PREFERENCES_FIELDS
    when 'all_fields'
      included_fields = Company::ALL_PREFERENCES_FIELDS
    end

    self.prefrences["default_fields"].each do |field|
      if included_fields.include?(field["id"])
        prefrences << { id: field["id"], name: field["name"], is_default: true}
      end
    end
    prefrences
  end

  def sandbox_trial_applicable
    limited_sandbox_access && account_type == 'sandbox'
  end

  def show_holiday_events?
    people_operations? || (onboarding? and enabled_time_off)
  end

  def get_hellosign_test_mode
    ['saplingapp.io', 'saplinghr.com', 'kallidus-suite.com'].include?(ENV['DEFAULT_HOST']) && (self.production? || self.implementation?) ? Company::HELLOSIGN_TEST_MODE_ENABLED : Company::HELLOSIGN_TEST_MODE_DISABLED
  end

  def company_trial_applicable
    limited_sandbox_access && account_type == 'trial' && company_trial_feature_flag && self.billing.present? && self.billing.trial_end_date?
  end

  def get_sa_custom_group
    sa_filters = self.smart_assignment_configuration.meta.dig("smart_assignment_filters")
    sa_filters ? self.custom_fields.where.not(field_type: :employment_status).where(id: sa_filters) : []
  end

  def get_field_type_by_name(name)
    self.custom_fields.find_by('name ILIKE ?', name).field_type rescue nil
  end

  def get_integration(api_identifier)
    integration_instances.find_by(api_identifier: api_identifier)
  end

  def convert_time(time, short_format=false)
    time_conversion_service.perform(time, short_format)
  end

  def exclude_preferences(excluding_ids)
    self.prefrences['default_fields'].reject{ |preference_field| excluding_ids.include?(preference_field['id']) }
  end

  def national_id_field_feature_flag
    feature_flag('national-id-field-type')
  end

  def create_ld_user_context(ld_user_key, include_custom=true)
    LaunchDarkly::LDContext.create({
                                     key: ld_user_key,
                                     kind: 'user',
                                     custom: include_custom ? { account_type: account_type, account_state: account_state } : nil
                                   }.compact)
  end

  private

  def time_conversion_service
    @time_conversion_service ||= TimeConversionService.new(self)
  end

  private

  def is_default_prefrences_changed?
    self.saved_change_to_prefrences? && self.saved_changes.has_key?('prefrences') && check_change_in_default_fields
  end

  def check_change_in_default_fields
    self.saved_changes['prefrences'].first['default_fields']&.pluck('id') != prefrences['default_fields']&.pluck('id')
  end

  def pto_digest_template(data, content)
    data.each do |user|
      content = content + "<div style='display: flex'><div><img style='width: 100px; height: 100px;' src= #{user[:member_avatar]} > </div>  <div> <span>#{user[:member_name]} </span> | <span> #{user[:member_title]}</span> | <span> #{user[:member_location]}</span><br/>"
      content = content + "<p> Taking #{user[:pto_amount]} of #{user[:pto_policy_name]} <br/> Starts #{user[:pto_start_date]}, returns #{user[:pto_return_date]}</p></div></div><br/><br/>"
    end
    content
  end

  def user_digest_template(data, content, type)
    data.each do |user|
      content = content + "<div style='display: flex'><div><img style='width: 100px; height: 100px;' src= #{user[:member_avatar]} > </div>  <div><span> #{user[:member_name]} </span> | <span> #{user[:member_title]}</span> | <span> #{user[:member_location]}</span><br/>"
      if type == 'anniversary'
        content = content + "<p> #{user[:work_ann_amount]} work Anniversary on #{user[:work_ann_date]}</p></div></div><br/><br/>"

      else
        content = content + "<p> Birthday on #{user[:bday_date]}</p></div></div><br/><br/>"
      end
    end
    content
  end

  def check_if_shib_attributes_exist?
    self.self_signed_attributes == {} || self.self_signed_attributes.blank? || (self.self_signed_attributes.present? && (self.self_signed_attributes["cert"].blank? || self.self_signed_attributes["private_key"].blank?)) rescue true
  end

  def update_calendar_events
    if self.enabled_calendar
      UpdateCalendarEventsJob.perform_in(2.second, {company_id: self.id,  create_events: true})
    else
      self.update_column(:token, nil)
      UpdateCalendarEventsJob.perform_in(2.second, {company_id: self.id,  create_events: false})
    end
  end

  def set_time_off_permissions
    self.user_roles.find_each do |user_role|
      apply_changes = false
      if user_role.permissions.try(:present?)
        if ['super_admin','admin'].include?(user_role.role_type) && user_role.is_time_off_admin_visibility_nil?
          user_role.permissions["admin_visibility"]["time_off"] = user_role.role_type == 'super_admin' ? 'view_and_edit' : 'view_only'
          apply_changes = true
        end
        # Set Platform visibility
        if user_role.is_time_off_platform_visibility_nil?
          user_role.permissions["platform_visibility"]["time_off"]  =  user_role.role_type == 'super_admin' ? 'view_and_edit' : 'no_access'
          apply_changes = true
        end
      end
      user_role.save if apply_changes
    end
  end

  def disable_time_off_custom_alerts
    self.custom_email_alerts.where(alert_type: [0, 1, 2, 3, 6]).update_all(is_enabled: false)
  end

  def self.upload_workday_fields(company_id, csv)
    CsvUploadWorkdayFieldsJob.new(company_id, csv.read).perform
  end

  def self.download_all_documents id, email
    DownloadAllDocumentsJob.perform_later(nil, nil, nil, id, email)
  end

  def self.download_profile_pictures(id, email)
    DownloadProfilePicturesJob.perform_later(id, email)
  end

  def self.create_assets params
    SandboxAutomation::CompanyAssetsCreationJob.perform_async(params.to_hash)
  end

  def self.upload_demo_users params
    SandboxAutomation::UploadDemoUsers.perform_async(params.to_hash)
  end

  def unset_shareable_url
    self.update_column(:token, nil)
  end

  def initialize_about_section
    self.about_section = { show: true, section_name: 'About us', section_title: "Let's learn the story of #{self.name}" }
  end

  def generate_webhook_token
    self.webhook_token = "#{SecureRandom.hex(15)}#{self.id}#{Time.now.to_i}"
  end

  def feature_flag key_name
    unless Rails.env.test?
      Rails.configuration.ld_client ||= LaunchDarkly::LDClient.new(ENV['LAUNCH_DARKLY_KEY']) unless Rails.configuration.try(:ld_client).present?
      flag_value_name = get_feature_flag_variation(key_name, name)
      get_feature_flag_variation('launch-darkly-key', name) ? (flag_value_name || get_feature_flag_variation(key_name, domain)) : flag_value_name
    else
      false
    end
  end

  def get_feature_flag_variation key_name, ld_user_key
    Rails.application.config.ld_client.variation(key_name, create_ld_user_context(ld_user_key), false)
  end

  def create_default_smart_assignment_configuration
    default_filters = ["loc", "dpt"]
    employment_status_id = self.custom_fields.where(field_type: 13).take&.id.to_s
    default_filters.push(employment_status_id)

    SmartAssignmentConfiguration.create!(company_id: self.id, meta: {"activity_filters": default_filters, "smart_assignment_filters": default_filters, "smart_assignment": true}) unless self.smart_assignment_configuration
  end

end
