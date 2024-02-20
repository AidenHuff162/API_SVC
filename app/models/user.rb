require 'nokogiri'
require 'gsuite/manage_account'

class User < ApplicationRecord
  extend FriendlyId
  extend Devise::Models
  include GsheetFieldValues
  include Friendlyable, UserStatisticManagement, LoggingManagement
  friendly_id :hash_id
  acts_as_paranoid
  has_paper_trail on: [:create, :update], unless: Proc.new { |u| u.saved_change_to_tokens? || u.saved_change_to_last_active? }
  devise :two_factor_authenticatable, :trackable, :recoverable, :omniauthable, :lockable,
         :registerable, authentication_keys: [:email], :omniauth_providers => [:google_oauth2, :azure_oauth2],
         :otp_secret_encryption_key => ENV['TWO_FACTOR_LOGIN_ENCRYPTION_KEY']

  include DeviseTokenAuth::Concerns::User
  include FieldAuditing
  include CommentManagement
  include CalendarEventsCrudOperations, GdprManagement
  attr_accessor :updated_from, :updated_by_admin, :is_current_stage_changed, :terminate_callback, :terminate_pto_callback, :manager_terminate_callback
  attr_accessor :invited_employee, :updating_integration, :allow_password_change, :pending_hire_id, :update_task_dates
  attr_accessor :notify_new_managers, :should_execute_offboarding_webhook, :skip_org_chart_callback

  include AlgoliaSearch
  include AASM
  include ADPHandler
  include IntegrationFilter
  include PtoRequests
  include EmailScheduleDate
  include GoogleCredentialStore, SlackCommandsOperations, UserIntegrationOperations
  # ALGOLIA_INDEX_NAME use only for non production environments
  algoliasearch if: :can_index?, auto_remove: false, force_utf8_encoding: true, index_name: "User_#{ENV['ALGOLIA_INDEX_NAME']}", disable_indexing: (Rails.env.test? || Rails.env.development?) do
    attribute :first_name, :last_name, :title, :company_id, :location_id, :team_id, :preferred_name, :picture
    attribute :location_name do
      if location.present?
        location.active? ? location.name : "#{location.name} (Inactive location)"
      else
        nil
      end
    end
    attribute :start_date do
      start_date.to_time.to_i rescue nil
    end
    attribute :current_stage do
      case current_stage
      when "invited"
        1
      when "preboarding"
        2
      when "registered"
        3
      when "offboarding"
        4
      when 'departed'
        5
      else
        0
      end
    end
    attribute :state do
      case state
      when "active"
        0
      when "inactive"
        1
      end
    end
    searchableAttributes ['preferred_name', 'first_name', 'last_name', 'title']
  end
  after_update do
    if offboarding_initiated?
      setup_calendar_event(self, 'last_day_worked', self.company)
    end
  end
  after_update :update_calendar_events, if: :saved_change_to_state?
  after_update :track_changed_fields, if: :can_create_history_entry?

  default_scope { where(visibility: :true) }
  scope :incomplete_documents_count_with_request, -> (user_id) { joins(:user_document_connections).where(id: user_id).where("user_document_connections.state <> ?", "draft").count }
  scope :not_inactive_incomplete, -> { where.not(state: 'inactive', current_stage: User.current_stages['incomplete']) }
  scope :headcount, -> (date) { where('start_date <= ?', date).where(super_user: false, state: :active, current_stage: [3, 4, 5, 6, 11, 13, 14]) }
  scope :spanbased_headcount, -> (start_date, end_date) { where('start_date >= ? && start_date <= ?', start_date, end_date).where(super_user: false, state: :active, current_stage: [3, 4, 5, 6, 11, 13, 14]) }
  scope :algolia_reindex, -> { joins(:company).where(companies: { account_state: :active }).where(super_user: false).where.not(current_stage: User.current_stages[:incomplete]).includes([:profile_image, :location]).reindex! }
  scope :not_incomplete, -> { where.not(current_stage: User.current_stages['incomplete']) }
  scope :hired_in_a_week, -> { where(start_date: 7.days.ago..Time.now) }
  scope :offboarded_in_a_week, -> { where(termination_date: 7.days.ago..Time.now) }
  scope :updated_in_a_week, -> { updated_in_days(7) }
  scope :arrived_and_active_in_range, -> (start_date, end_date) { where.not('current_stage IN (?) OR (is_rehired = true AND current_stage IN (?))', [0, 1, 2, 8, 12], [8, 12]).where('start_date >= ? AND start_date <= ?', start_date, end_date) }
  scope :active_till_date, -> (date) { where(current_stage: [3, 4, 5, 6, 7, 11, 13, 14]).where('start_date <= ?', date).where('termination_date IS NULL OR termination_date > ?', date) }
  scope :departed_in_range, -> (start_date, end_date) { where('termination_date >= ? AND termination_date <= ?', start_date, end_date) }
  scope :user_incomplete_paperwork_requests_count, -> (user_id) { joins(:paperwork_requests).where(id: user_id).where('paperwork_requests.state IN (?)', ['preparing', 'assigned', 'failed']).count }
  scope :user_incomplete_co_signer_paperwork_requests_count, -> (user_id) { joins(:paperwork_requests).where(id: user_id).where('paperwork_requests.co_signer_id = ? AND paperwork_requests.state = ?', user_id, 'signed').count }
  scope :user_incomplete_upload_requests_count, -> (user_id) { joins(:user_document_connections).where(id: user_id).where('user_document_connections.state = ?', 'request').count }
  scope :users_with_new_ui_enabled, -> { where(ui_switcher: :true) }
  scope :updated_in_days, -> (day) { joins(:profile).where('(users.id IN (SELECT DISTINCT(field_auditable_id) FROM field_histories where field_auditable_type=? AND created_at > ?)) OR (profiles.id IN (SELECT DISTINCT(field_auditable_id) FROM field_histories where field_auditable_type=? AND created_at > ?))', "User", day.days.ago, "Profile", day.days.ago) }
  scope :with_workday, -> { where.not(workday_id: nil) }
  scope :unsynced_users, -> (integration) {where("current_stage NOT IN (?) AND #{integration.downcase.gsub(' ', '_')}_id IS NULL AND super_user = ?", [User.current_stages[:incomplete], User.current_stages[:invited]], false) }

  after_save :algolia_attributes_changed?
  after_update :lock_user, if: :saved_change_to_failed_attempts?
  after_update :update_termination_snapshot, if: Proc.new { |u| (u.saved_change_to_termination_date? || u.saved_change_to_last_day_worked?) && u.terminate_callback.blank? }
  after_update :offboard_user, if: :saved_change_to_termination_date?
  after_update :update_anniversary_events, if: Proc.new { |u| u.saved_change_to_start_date? && !u.super_user?}
  after_commit :update_assigned_policies_dates, if: Proc.new { |u| u.saved_change_to_start_date? }
  after_update :update_first_day_snapshots, if: Proc.new { |u| u.saved_change_to_start_date? && u.terminate_callback.blank? }
  after_commit :update_tasks_date, if: Proc.new { |u| u.saved_change_to_start_date? }
  after_update :send_new_manager_email, if: Proc.new { |u| u.saved_change_to_manager_id? }
  after_update :remove_manager_tasks, if: Proc.new { |u| u.saved_change_to_manager_id? && u.manager_id.blank? }

  after_update do
    if calendar_event_related_fields_changed['event_changed'] && self.active?
      update_user_event_date_range(self, calendar_event_related_fields_changed['changed_attribute'])
    end
  end
  before_destroy :auto_denny_related_pto_requests
  before_destroy :free_manager_role
  before_destroy :nullify_accounnt_creator_id
  before_destroy :destroy_pre_start_email_jobs
  before_destroy :update_comments_description_for_mentioned_users
  before_destroy :expire_cache
  after_destroy :remove_from_algolia, if: Proc.new { Rails.env.test?.blank? }
  before_create :initialize_preboarding_progress
  after_create :set_guid
  after_create :manage_two_factor_authentication, if: Proc.new { |u| u.company.otp_required_for_login? || u.super_user? }
  after_update :manage_two_factor_authentication, if: Proc.new { |u| (u.company&.otp_required_for_login? || u.super_user?) && (u.saved_change_to_otp_required_for_login? || (u.saved_change_to_show_qr_code? && u.show_qr_code?)) && u.otp_required_for_login? }
  after_update { enforce_general_data_protection_regulation_on_termination_date_change(self) if !is_gdpr_action_taken.present? && !saved_change_to_location_id? && saved_change_to_termination_date? && self.departed? }
  after_update { enforce_general_data_protection_regulation_on_location_change(self) if !is_gdpr_action_taken.present? && saved_change_to_location_id? && self.departed? }
  after_update :cancel_inactive_pto_requests, if: Proc.new { |u| u.saved_change_to_current_stage? && u.departed? }
  after_commit :execute_offboarding_webhook, if: :should_execute_offboarding_webhook

  RPFLD_DELIMITER = "\n"
  NULL_ATTRS = %w( email personal_email )
  AUDITING_FIELDS = ['email', 'personal_email', 'first_name', 'last_name', 'team_id', 'location_id', 'role', 'start_date', 'manager_id', 'title', 'state', 'termination_date', 'buddy_id', 'current_stage', 'preferred_name', 'job_tier', 'last_day_worked', 'termination_type', 'eligible_for_rehire', 'preferred_full_name', 'working_pattern_id'].freeze
  ACTIVE_CURRENT_STAGES = ['first_week', 'first_month', 'ramping_up', 'offboarding', 'registered', 'last_month', 'last_week'].freeze
  INACTIVE_CURRENT_STAGES = ['invited', 'preboarding', 'pre_start', 'departed', 'incomplete', 'no_activity'].freeze
  DATE_TYPE_DEFAULT_FIELDS = %w(start_date last_day_worked termination_date)
  before_save :nil_if_blank

  belongs_to :company, counter_cache: true
  counter_culture :company, column_name: proc { |model| model.people_validate? ? 'people_count' : nil },
                  column_names: { ["users.super_user = false AND users.state = 'active' AND users.start_date <= ?", Date.today] => 'people_count' }
  belongs_to :team, counter_cache: true
  belongs_to :location, counter_cache: true
  belongs_to :manager, class_name: 'User'
  belongs_to :buddy, class_name: 'User'
  belongs_to :account_creator, class_name: 'User'
  belongs_to :onboarding_profile_template, class_name: 'ProfileTemplate', foreign_key: :onboarding_profile_template_id
  belongs_to :offboarding_profile_template, class_name: 'ProfileTemplate', foreign_key: :offboarding_profile_template_id
  has_many :pto_balance_audit_logs, dependent: :destroy
  has_many :assigned_pto_policies, dependent: :destroy
  has_many :unassigned_pto_policies, dependent: :destroy
  has_many :pto_policies, through: :assigned_pto_policies
  has_many :all_managed_users, -> (user) { where(company_id: user.company_id) }, class_name: 'User', foreign_key: :manager_id, dependent: :nullify
  # When you change managed_users kindly update the cache accordingly
  has_many :managed_users, -> { where.not("current_stage IN (?) OR state = 'inactive'", [User.current_stages[:incomplete], User.current_stages[:departed]]) }, class_name: 'User', foreign_key: :manager_id, dependent: :nullify
  has_many :active_managed_users, -> { where(state: 'active') }, class_name: 'User', foreign_key: :manager_id, dependent: :nullify
  has_many :managed_approval_chain_users, -> { where.not("current_stage IN (?)", [User.current_stages[:incomplete]]) }, class_name: 'User', foreign_key: :manager_id, dependent: :nullify
  has_many :buddy_users, class_name: 'User', foreign_key: :buddy_id, dependent: :nullify
  has_many :account_created_users, class_name: 'User', foreign_key: :account_creator_id, dependent: :nullify
  has_many :teams, foreign_key: :owner_id, dependent: :nullify
  has_many :locations, foreign_key: :owner_id, dependent: :nullify
  has_many :task_user_connections
  has_many :assignees, -> { where.not("current_stage IN (?) OR users.state = 'inactive'", [User.current_stages[:incomplete], User.current_stages[:departed]]).where("task_user_connections.before_due_date <= ? OR task_user_connections.before_due_date IS NULL", Date.today).reorder('').group(:id) }, through: :task_user_connections, source: :owner
  has_many :paperwork_requests, dependent: :destroy
  has_many :assigned_paperwork_requests, -> { where("paperwork_requests.state <> ?", "draft") }, through: :paperwork_requests, source: :user
  has_many :paperwork_requests_to_co_sign, -> { where(state: 'signed') }, class_name: 'PaperworkRequest', foreign_key: :co_signer_id, dependent: :nullify
  has_many :outstanding_paperwork_requests, -> (object) { where(state: 'assigned') }, class_name: 'PaperworkRequest', foreign_key: :user_id
  has_many :user_document_connections, dependent: :destroy
  has_many :created_user_document_connections, class_name: "UserDocumentConnection", foreign_key: :created_by_id, dependent: :destroy
  has_many :custom_field_values, dependent: :destroy
  has_many :custom_field_coworker, class_name: 'CustomFieldValue', foreign_key: :coworker_id, dependent: :destroy
  has_many :pto_requests, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :user_emails, dependent: :destroy
  has_one :anonymized_datum, dependent: :destroy
  has_one :deleted_user_email, dependent: :destroy
  has_one :google_credential, as: :credentialable, dependent: :destroy

  has_many :task_owner_connections, -> { joins(:task).where.not(tasks: { task_type: '4' }) }, class_name: 'TaskUserConnection', foreign_key: :owner_id
  has_many :tasks, foreign_key: :owner_id
  has_many :outstanding_task_owner_connections, -> (object) { where("task_user_connections.state = ?", 'in_progress').joins(:user).where("users.current_stage NOT IN (?) AND users.state = 'active' AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", [User.current_stages[:incomplete], User.current_stages[:departed]], Sapling::Application::ONBOARDING_DAYS_AGO).joins(:task).where.not(tasks: { task_type: '4' }) }, class_name: 'TaskUserConnection', foreign_key: :owner_id

  has_many :outstanding_task_user_connections, -> (object) { where("task_user_connections.state = ?", 'in_progress') }, class_name: 'TaskUserConnection', foreign_key: :user_id
  has_many :recommendation_feedbacks, foreign_key: :recommendation_owner_id
  has_one :recommendation_feedback, foreign_key: :recommendation_user_id
  has_one :profile_image, as: :entity, dependent: :destroy,
          class_name: 'UploadedFile::ProfileImage'
  has_one :owned_company, foreign_key: :owner_id, class_name: 'Company', dependent: :nullify
  has_one :company_opertaion_contact, foreign_key: :operation_contact_id, class_name: 'Company', dependent: :nullify
  has_one :profile, dependent: :destroy
  has_many :created_users, class_name: 'User', foreign_key: :created_by_id, dependent: :nullify
  belongs_to :creator, class_name: 'User', foreign_key: :created_by_id
  has_many :special_document_upload_requests, foreign_key: :special_user_id, class_name: 'DocumentUploadRequest', dependent: :destroy
  has_many :outstanding_upload_requests, -> (object) { where(state: 'request') }, class_name: 'UserDocumentConnection', foreign_key: :user_id
  has_many :histories, dependent: :destroy
  has_many :history_users, dependent: :destroy
  has_many :representative_paperwork_templates, class_name: "PaperworkTemplate", foreign_key: :representative_id, dependent: :nullify
  belongs_to :user_role
  has_many :reports, dependent: :nullify
  has_many :calendar_feeds, dependent: :destroy
  has_many :created_document_upload_requests, class_name: :DocumentUploadRequest, foreign_key: "user_id"
  has_many :paperwork_packets, -> { where(deleted_at: nil) }
  has_many :paperwork_templates
  has_many :created_field_hisotries, class_name: :FieldHistory, foreign_key: 'field_changer_id'
  has_many :field_histories, as: :field_auditable
  has_one :owned_custom_group, class_name: :CustomFieldOption, foreign_key: "owner_id", dependent: :nullify
  has_one :pending_hire, -> { with_deleted.order(created_at: :desc) }, dependent: :destroy
  has_one :organization_root_company, class_name: :Company, foreign_key: "organization_root_id", dependent: :nullify
  has_many :comments, class_name: "Comment", foreign_key: :commenter_id, dependent: :destroy
  has_many :activities, class_name: "Activity", foreign_key: :agent_id, dependent: :destroy
  has_many :calendar_events, as: :eventable, dependent: :destroy
  has_many :birthday_calendar_events, -> { where(event_type: :birthday) }, as: :eventable, dependent: :destroy, class_name: 'CalendarEvent'
  has_many :workspace_members, foreign_key: :member_id, dependent: :destroy
  has_many :workspaces, through: :workspace_members
  has_many :personal_documents, dependent: :destroy
  has_many :created_personal_documents, class_name: "PersonalDocument", foreign_key: :created_by_id, dependent: :destroy
  has_many :update_custom_snapshots, class_name: :CustomTableUserSnapshot, foreign_key: 'edited_by_id', dependent: :nullify
  has_many :update_custom_eamil_alerts, class_name: :CustomEmailAlert, foreign_key: 'edited_by_id', dependent: :nullify
  has_many :custom_table_user_snapshots, dependent: :destroy
  has_many :custom_section_approvals, dependent: :destroy
  has_many :requested_custom_section_approvals, -> (object) { where(state: 'requested') }, class_name: "CustomSectionApproval", dependent: :destroy
  has_many :custom_section_approval_requests, class_name: 'CustomSectionApproval', foreign_key: :requester_id
  has_many :updated_api_keys, class_name: :ApiKey, foreign_key: 'edited_by_id', dependent: :nullify
  has_many :request_informations, foreign_key: :requester_id, dependent: :nullify
  has_many :request_informations, foreign_key: :requested_to_id, dependent: :destroy
  has_many :custom_table_user_snapshot_requests, class_name: :CustomTableUserSnapshot, foreign_key: 'requester_id', dependent: :nullify
  has_many :ctus_approval_chains, class_name: :CtusApprovalChain, foreign_key: 'approved_by_id'
  has_many :cs_approval_chains, class_name: :CsApprovalChain, foreign_key: 'approver_id'
  has_many :update_paperwork_packets, class_name: "PaperworkPacket", foreign_key: 'updated_by_id', dependent: :nullify

  has_many :created_webhooks, class_name: :Webhook, foreign_key: 'created_by_id', dependent: :nullify
  has_many :updated_webhooks, class_name: :Webhook, foreign_key: 'updated_by_id', dependent: :nullify
  has_many :webhook_events, class_name: :WebhookEvent, foreign_key: 'triggered_for_id', dependent: :nullify
  has_many :triggered_webhook_events, class_name: :WebhookEvent, foreign_key: 'triggered_by_id', dependent: :nullify
  has_many :sftps, foreign_key: 'updated_by_id', dependent: :nullify

  delegate :name, to: :location, prefix: :location, allow_nil: true

  after_create :track_changed_fields, if: :can_create_history_entry?
  validate :password_complexity
  before_validation :downcase_emails, if: Proc.new { |u| u.will_save_change_to_email? || u.will_save_change_to_personal_email? }
  before_validation :update_onboard_email, if: Proc.new { |u| u.will_save_change_to_email? || u.will_save_change_to_personal_email? }
  after_save :assign_manager_role, if: Proc.new { |u| u.saved_change_to_manager_id? }
  before_update :update_hellosign_signature_email, if: Proc.new { |u| u.changes_to_save["email"].present? || u.will_save_change_to_personal_email? }
  after_update :manage_two_factor_authentication, if: Proc.new { |u| (u.company&.otp_required_for_login? || u.super_user?) && u.otp_required_for_login? && (u.saved_change_to_email? || u.saved_change_to_personal_email?) }

  validates_presence_of :personal_email, if: Proc.new { (onboard_email && (onboard_email == 'personal' || onboard_email == 'both')) || (!onboard_email && !email.present?) }
  validates_presence_of :email, if: Proc.new { (onboard_email && (onboard_email == 'company' || onboard_email == 'both')) || (!onboard_email && !personal_email.present?) }
  validates_presence_of :state
  validates :password, length: { in: 8 .. 128 }, if: Proc.new { |u| u.password.present? }
  validate :validate_onboarding_profile_template
  validate :validate_offboarding_profile_template
  validates :password, password_strength: {min_entropy: 10, min_word_length: 8, use_dictionary: false, extra_dictionary_words: :password_extra_words}, on: :update, :if => lambda {|user| user.will_save_change_to_encrypted_password? }
  validate :validate_emails, if: Proc.new { (self.changes_to_save.keys & ['email', 'personal_email']).present? }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "Only allows valid emails" }, allow_blank: true, if: Proc.new{ |u| u.will_save_change_to_email? }
  validates :personal_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "Only allows valid personal emails" }, allow_blank: true, if: Proc.new{ |u| u.will_save_change_to_personal_email? }
  validates_with UpdateUserCompanyValidator
  validates_format_of :first_name, :last_name, :title, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  before_save :remove_spacing_in_name
  before_save :update_preferred_full_name, if: Proc.new{ |u| u.will_save_change_to_preferred_name? || u.will_save_change_to_first_name? || u.will_save_change_to_last_name? }
  after_create :set_calendar_events_settings
  after_create :update_last_modified_at
  after_create :create_profile
  after_create :update_admin_role
  after_create :create_calendar_events, if: Proc.new { |u| !u.super_user? }
  after_create :set_uid
  after_create :assign_default_policy, if: Proc.new { |u| u.company.enabled_time_off and u.company.pto_policies.present? && u.terminate_pto_callback.blank? }
  after_create :buddy_email, if: Proc.new { |u| u.buddy.present? }
  after_create :after_create_manager_email, if: Proc.new { |u| u.manager.present? && !u.incomplete? }
  after_save :inactive_user_on_departed, if: Proc.new { |u| u.saved_change_to_current_stage? && u.active? && u.current_stage == 'departed' && is_access_removed? }
  after_update :update_free_admin_role, if: Proc.new { |u| u.saved_change_to_manager_id? && u.manager_id_before_last_save != nil }
  after_update :logout_user, if: Proc.new { |u| u.saved_change_to_state? && u.inactive? }
  after_update :update_admin_role, if: Proc.new { |u| u.saved_change_to_role? }
  after_update :update_user_role, if: Proc.new { |u| u.saved_change_to_user_role_id? }
  after_update :manager_form_completion, if: Proc.new { |u| u.saved_change_to_manager_id? && u.manager_id_before_last_save == nil }
  after_update :notify_account_creator_about_manager_form_completion, if: Proc.new { |u| u.saved_change_to_is_form_completed_by_manager? && u.is_form_completed_by_manager == 'completed' }
  after_update :notify_user_about_change_in_start_date, if: Proc.new { |u| u.saved_change_to_start_date? }
  after_update :buddy_email, if: Proc.new { |u| !u.incomplete? && !u.departed? && u.active? && u.buddy_id && u.saved_change_to_buddy_id? }
  after_update :fix_counters, if: :current_state_or_counter_changed?
  after_update :update_assigned_policies, if: Proc.new { |u| u.saved_change_to_location_id? || u.saved_change_to_team_id? }
  after_update :flush_location_and_team_cache, if: Proc.new { |u| u.saved_change_to_location_id? || u.saved_change_to_team_id? }
  after_commit :update_manager_activites_over_the_night, if: Proc.new { |u| u.saved_change_to_manager_id? && u.manager_terminate_callback.blank? }

  after_update :remove_information_on_inactive, if: Proc.new { |u| u.saved_change_to_state? && u.inactive? && !u.departed? }
  after_update :restore_information_on_active, if: Proc.new { |u| u.saved_change_to_state? && u.active? && u.state_before_last_save == 'inactive' }
  after_update :preboarding_finished, if: Proc.new { |u| u.is_finishing_preboarding? && !@is_current_stage_changed.present? }
  after_update :onboarding_finished, if: Proc.new { |u| u.saved_change_to_current_stage? && !u.onboarding_completed && u.active? && u.current_stage_before_last_save == 'incomplete' && u.current_stage == 'invited' }
  after_update :update_current_stage_on_start_date_change, if: Proc.new { |u| u.saved_change_to_start_date? && !@is_current_stage_changed }
  after_update :update_current_stage_on_termination_date_change, if: Proc.new { |u| u.saved_change_to_termination_date? && !@is_current_stage_changed }

  after_update :run_update_organization_chart_job, if: Proc.new { |u| !u.skip_org_chart_callback && (u.saved_change_to_first_name? || u.saved_change_to_last_name? || u.saved_change_to_preferred_name? || u.saved_change_to_title? || u.saved_change_to_last_day_worked? || u.saved_change_to_start_date? || u.saved_change_to_location_id? || u.saved_change_to_team_id?) }
  after_update :run_create_organization_chart_job, if: Proc.new { |u| !u.skip_org_chart_callback && (u.saved_change_to_manager_id? || u.saved_change_to_state? && u.state == "inactive" || update_org_chart_on_current_stage_changed?) }

  after_update :update_task_due_dates, if: Proc.new { |u| ((u.saved_change_to_termination_date? && u.termination_date) || (u.saved_change_to_last_day_worked? && u.last_day_worked)) }
  after_update :remove_buddy_tasks, if: proc { |u| u.saved_change_to_buddy_id? && u.buddy_id.nil? }

  before_validation :reset_current_user_for_test_env, if: :if_evn_test?

  after_restore :restore_on_algolia

  before_real_destroy :really_destroy_soft_deleted_relations
  after_real_destroy :remove_from_algolia, if: Proc.new { Rails.env.test?.blank? }

  after_destroy :destroy_task_owner_connections
  after_destroy :run_create_organization_chart_job #Don't show delete user in the organization chart
  after_restore :run_create_organization_chart_job

  # after_save :expire_cache
  after_save :flush_cache

  #ROI management
  after_create { log_onboarded_user_id if self.incomplete?.blank? }
  after_save { log_onboarded_user_id if current_stage_before_last_save == 'incomplete' && saved_change_to_current_stage? }
  after_save { log_loggedin_user_id if self.saved_change_to_last_sign_in_at? || self.saved_change_to_last_active? }

  accepts_nested_attributes_for :profile
  before_validation :ensure_manager_form_token
  before_validation :ensure_request_information_form_token

  before_restore :restore_user_email
  after_destroy :anonymise_user_email
  after_commit :manage_user_state_in_adfs, if: Proc.new { |u| u.active_directory_object_id.present? && ((u.saved_change_to_current_stage? && u.termination_date.present? && u.departed?) || u.saved_change_to_state?) }

  after_save :set_super_user_status, if: Proc.new { |u| (u.saved_change_to_email? || u.saved_change_to_personal_email?) && u.account_owner? && u.email&.include?('@' + u.company.domain) && u.personal_email&.include?('@' + u.company.domain) }
  after_commit :create_webhook_events, if: Proc.new { |u| u.saved_change_to_current_stage? }
  after_update { logout_user if self.saved_change_to_user_role_id? }

  enum role: {
    employee: 0,
    admin: 1,
    account_owner: 2
  }

  enum onboard_email: {
    personal: 0,
    company: 1,
    both: 2
  }

  enum is_form_completed_by_manager: {
    no_fields: 0,
    incompleted: 1,
    completed: 2
  }

  enum created_by_source: {
    sapling: 0,
    namely: 1,
    bamboo: 2
  }

  enum termination_type: {
    voluntary: 0,
    involuntary: 1,
    other: 2
  }

  enum eligible_for_rehire: {
    yes: 0,
    no: 1,
    upon_review: 2
  }

  enum current_stage: {
    invited: 0,
    preboarding: 1,
    pre_start: 2,
    first_week: 3,
    first_month: 4,
    ramping_up: 5,
    offboarding: 6,
    departed: 7,
    incomplete: 8,
    registered: 11,
    no_activity: 12,
    last_month: 13,
    last_week: 14
  }

  enum send_credentials_type: {
    immediately: 0,
    before: 1,
    on: 2,
    dont_send: 3
  }

  enum remove_access_timing: {
    default: 0,
    remove_immediately: 1,
    custom_date: 2
  }

  enum remove_access_state: {
    pending: 0,
    removed: 1
  }

  LOCK = Mutex.new
  
  def is_complete
    self.incomplete?.blank?
  end

  def can_index?
    is_complete && !self.super_user?
  end

  def set_uid
    self.update_column(:uid, self.id)
  end

  def read_and_store_credentials_in_db(credential)
    read_and_store_google_credentials(credential)
  end

  def remove_role
    if self.user_role.name == 'Ghost Admin'
      self.destroy
    else
      self.user_role_id = nil
      self.update_user_role
    end
  end

  def employee_type
    Rails.cache.fetch("#{self.id}/employee_type", expires_in: 24.hours) do
      self.employee_type_field_option&.option
    end
  end

  def password_extra_words
    [self.first_name, self.last_name, self.preferred_name, self.email, self.personal_email]
  end

  def employee_type_field_option
    self.custom_field_values.find_by(custom_field_id: self.company.custom_fields.find_by(field_type: 13)&.id)&.custom_field_option
  end

  def set_employee_type_field_option(option_id)
    self.custom_field_values.find_or_create_by(custom_field: self.company.custom_fields.find_by(field_type: 13))&.update(custom_field_option_id: option_id)
  end

  def set_custom_group_field_option(field_id, option_id)
    self.custom_field_values.find_or_create_by(custom_field_id: field_id)&.update(custom_field_option_id: option_id)
  end

  def get_team_name
    serializ_team = self.get_cached_team
    serializ_team[:name] if serializ_team.present?
  end

  def can_manage_integrations?
    self.present? && self.user_role.present? && self.user_role.permissions['admin_visibility'].present? && self.user_role.permissions['admin_visibility']['integrations'].present? && self.user_role.permissions['admin_visibility']['integrations'] == 'view_and_edit'
  end

  def destroy_all_incomplete_emails
    self.user_emails.where(email_status: UserEmail::statuses[:incomplete]).delete_all
  end

  def schedule_default_onboarding_emails current_user_id
    collection_params = { invitation: true } #Fetch only onboarding and emails related to company
    collection = fetch_email_templates(collection_params)
    collection.results.each do |email|
      self.create_user_email(email, UserEmail.scheduled_froms[:onboarding], nil, current_user_id)
    end
  end

  def send_new_manager_email
    if (self.notify_new_managers || self.company.manager_emails) && self.manager_id && self.manager && !self.departed? && !self.inactive?
      UserMailer.buddy_manager_change_email(self.id, self.manager_id, (self.manager.email || self.manager.personal_email), 'new_manager', nil, false, 'Manager').deliver_now!
    end
  end

  def create_user_email(template, scheduled_from, params = nil, current_user_id = nil)
    schedule_options = template.schedule_options
    template_attachments = []

    template.attachments.find_each do |attachment|
      template_attachment = {}
      template_attachment[:id] = attachment.id

      template_attachment[:download_url] = attachment.file.download_url(attachment.original_filename)
      template_attachment[:original_filename] = attachment.original_filename
      template_attachments.push(template_attachment)
    end

    template_name = ActionView::Base.full_sanitizer.sanitize(template.name)
    if template.name.include? "---"
      template_name = template.name.split('---')[-1]
    end
    user_email = self.user_emails.new({
                                        subject: template.subject,
                                        cc: template.cc,
                                        bcc: template.bcc,
                                        description: template.description,
                                        email_type: template.email_type,
                                        template_name: template_name,
                                        sent_at: nil,
                                        email_status: 4,
                                        scheduled_from: scheduled_from,
                                        schedule_options: schedule_options,
                                        template_attachments: template_attachments,
                                        editor_id: current_user_id
                                      })
    if scheduled_from == UserEmail.scheduled_froms[:offboarding]
      user_email.schedule_options['last_day_worked'] = params[:last_day_worked]
      user_email.schedule_options['termination_date'] = params[:termination_date]
    end
    user_email.invite_at = Inbox::SetInviteAt.new.set_invite_at(user_email)
    if schedule_options['to'].present?
      user_email.to = get_user_email(schedule_options['to']) if schedule_options['to'].present?
    else
      user_email.to = user_email.get_to_email_list
    end
    user_email.from = schedule_options['from'] if schedule_options['from'].present?
    user_email.save
    # user_email.assign_template_attachments(template.attachments) if template.attachments
  end

  def assign_default_offboarding_emails(params = nil, current_user_id)
    #Fetch only offboarding and emails related to company
    collection_params = { smart_assignment: self.smart_assignment, offboarding: true, email_type: 'offboarding', location_id: params[:location_id],
                          team_id: params[:team_id], employment_status_id: params[:employment_status_id], custom_groups: params[:custom_groups] }
    collection = fetch_email_templates(collection_params.with_indifferent_access)
    collection.results.each do |email|
      self.create_user_email(email, UserEmail.scheduled_froms[:offboarding], params, current_user_id)
    end
  end

  def destroy_task_owner_connections
    self.task_owner_connections.destroy_all
    self.task_user_connections.destroy_all
    self.tasks.destroy_all
  end

  def reassign_manager_activities(old_manager_id, new_manager_id)
    self.reassign_activities(old_manager_id, new_manager_id, 2, 'manager')
  end

  def reassign_buddy_activities(old_buddy_id, new_buddy_id)
    self.reassign_activities(old_buddy_id, new_buddy_id, 3, 'buddy')
  end

  def set_fields_by_pending_hire(fields, is_using_custom_table)
    default_fields = []
    custom_field_data = []
    old_user = User.find(self.id)

    fields.each do |field|
      custom_field_data.push({ name: 'Home Address', old_value: self.get_custom_field_value_text('Home Address') }) if ['line1', 'line2', 'city', 'address_state', 'zip'].include?(field[:attribute]) && custom_field_data.select { |e| e[:name] == 'Home Address' }.length == 0

      if field[:attribute] == 'first_name'
        self.first_name = field[:new]
      elsif field[:attribute] == 'last_name'
        self.last_name = field[:new]
      elsif field[:attribute] == 'phone_number'
        CustomFieldValue.set_custom_field_value(self, 'Mobile Phone Number', field[:new], 'Phone', true, nil, false, true)
        custom_field_data.push({ name: 'Mobile Phone Number', old_value: field[:old] })
      elsif field[:attribute] == 'start_date'
        self.start_date = field[:new].to_date
      elsif field[:attribute] == 'line1'
        CustomFieldValue.set_custom_field_value(self, 'Home Address', field[:new], 'Line 1', false)
      elsif field[:attribute] == 'line2'
        CustomFieldValue.set_custom_field_value(self, 'Home Address', field[:new], 'Line 2', false)
      elsif field[:attribute] == 'city'
        CustomFieldValue.set_custom_field_value(self, 'Home Address', field[:new], 'City', false)
      elsif field[:attribute] == 'address_state'
        CustomFieldValue.set_custom_field_value(self, 'Home Address', field[:new], 'State', false)
      elsif field[:attribute] == 'zip'
        CustomFieldValue.set_custom_field_value(self, 'Home Address', field[:new], 'Zip', false)
      elsif !is_using_custom_table && field[:attribute] == 'jt'
        self.title = field[:new]
        field[:attribute] = 'title'
      elsif !is_using_custom_table && field[:attribute] == 'loc'
        self.location_id = self.company.locations.where("name ILIKE ?", field[:new]).take.try(:id)
        field[:attribute] = 'location_id'
      elsif !is_using_custom_table && field[:attribute] == 'dpt'
        self.team_id = self.company.teams.where("name ILIKE ?", field[:new]).take.try(:id)
        field[:attribute] = 'team_id'
      elsif !is_using_custom_table && field[:attribute] == 'man'
        self.manager_id = self.pending_hire.manager_id
        field[:attribute] = 'manager_id'
      elsif !is_using_custom_table && field[:attribute] == 'Employment Status'
        CustomFieldValue.set_custom_field_value(self, 'Employment Status', field[:new])
        custom_field_data.push({ name: 'Employment Status', old_value: field[:old] })
      end

      default_fields.push(field[:attribute]) if ['first_name', 'last_name', 'start_date', 'title', 'location_id', 'team_id', 'manager_id'].include?(field[:attribute])
    end

    self.terminate_callback = true
    self.save
    begin
      WebhookEvents::ManageWebhookPayloadJob.perform_async(self.company_id, { default_data_change: default_fields, user: self.id, temp_user: old_user.attributes, webhook_custom_field_data: custom_field_data })
    rescue Exception => e
      puts e.message
    end
  end

  def reassign_activities(old_manager_or_buddy_id, new_manager_or_buddy_id, task_type, outcome_type)
    TaskUserConnection.joins(:task)
                      .where(tasks: { task_type: task_type }, user_id: self.id, state: ['draft', 'in_progress'], owner_id: old_manager_or_buddy_id)
                      .update_all(owner_id: new_manager_or_buddy_id)

    User.find_by(id: old_manager_or_buddy_id).try(:fix_counters)
    User.find_by(id: new_manager_or_buddy_id).try(:fix_counters)
  end

  def get_cached_team
    Team.cached_team_serializer(self.team_id) if self.team_id.present?
  end

  def get_cached_location
    Location.cached_location_serializer(self.location_id) if self.location_id
  end

  def get_location_name
    serializ_location = self.get_cached_location
    serializ_location[:name] if serializ_location.present?
  end

  def flush_location_and_team_cache
    if self.saved_change_to_location_id?
      Location.expire_people_count(self.location_id_before_last_save)
      Location.expire_people_count(self.location_id)
    else
      Team.expire_people_count(self.team_id_before_last_save)
      Team.expire_people_count(self.team_id)
    end
  end

  def ensure_manager_form_token
    unless self.manager_form_token
      raw, enc = Devise.token_generator.generate(self.class, :manager_form_token)
      self.manager_form_token = enc
    end
    self.manager_form_token
  end

  def ensure_request_information_form_token
    unless self.request_information_form_token
      raw, enc = Devise.token_generator.generate(self.class, :request_information_form_token)
      self.request_information_form_token = enc
    end
    self.request_information_form_token
  end

  def cancel_offboarding
    self.last_day_worked = nil
    self.termination_type = nil
    self.termination_date = nil
    self.eligible_for_rehire = nil
    self.state = 'active'
    self.remove_access_state = "pending"
    if self.is_rehired?
      self.gsuite_account_deprovisioned = false
      user_emails = self.user_emails.where(email_status: [UserEmail::statuses[:scheduled], UserEmail::statuses[:rescheduled]]).includes(:invite)
    else
      self.current_stage = :pre_start
      user_emails = self.user_emails.where(email_status: [UserEmail::statuses[:incomplete], UserEmail::statuses[:scheduled], UserEmail::statuses[:rescheduled]], scheduled_from: UserEmail.scheduled_froms[:offboarding]).includes(:invite)
    end
    self.save!
    self.onboarding!
    self.task_user_connections.where(is_offboarding_task: true).try(:each) do |tuc|
      tuc.really_destroy!
    end
    if user_emails.present?
      create_general_logging(self.company, 'Destroy incomplete and scheduled Email', { result: "Destroy all scheduled emails #{user_emails.ids} for user id #{self.id} during cancel offboarding" })
      user_emails.find_each do |user_email|
        user_email.deleted!
      end
    end

    SsoIntegrations::Gsuite::ReactivateGsuiteProfile.perform_async(self.id) if !self.gsuite_account_exists
    reset_pto_balances
    reactivate_profiles(self) if self.is_rehired?
  end

  def downcase_emails
    self.personal_email = self.personal_email.try(:downcase)
    self.email = self.email.try(:downcase)
  end

  def update_onboard_email
    if !self.email && (!self.onboard_email || self.onboard_email == 'both' || self.onboard_email == 'company')
      self.onboard_email = User.onboard_emails[:personal]
    elsif !self.personal_email && (!self.onboard_email || self.onboard_email == 'both' || self.onboard_email == 'personal')
      self.onboard_email = User.onboard_emails[:company]
    elsif self.personal_email && self.email && !self.onboard_email
      self.onboard_email = User.onboard_emails[:both]
    end
  end

  # Cached Methodss

  def get_cached_about_you
    Rails.cache.fetch([self.id, 'cached_profile_about_you'], expires_in: 5.days) { self.profile.about_you if self.profile.present? && self.profile.deleted_at.nil? }
  end

  def cached_managed_user_ids
    self.managed_users.ids
  end

  def is_access_permission_change_requested
    self.custom_section_approvals.where(state: CustomSectionApproval.states[:requested]).joins(:requested_fields).pluck(:preference_field_id).include? ('access_permission')
  end

  def get_cached_role_name(approval_profile_page = nil)
    if approval_profile_page.present? && is_access_permission_change_requested
      self.user_role_name
    else
      Rails.cache.fetch([self.id, 'role_name'], expires_in: 10.days) do
        self.user_role_name
      end
    end
  end

  def flush_cached_role_name
    Rails.cache.delete([self.id, 'role_name'])
    true
  end

  def expire_cache
    if self.saved_change_to_current_stage? || self.saved_change_to_state? || self.saved_change_to_manager_id?
      self.flush_managed_user_count(self.manager_id_before_last_save, self.manager_id)
    end
    Team.expire_people_count(self.team_id) if self.team_id.present?
    Location.expire_people_count(self.location_id) if self.location_id.present?
    Rails.cache.delete([self.id, 'managed_user_count'])
    Rails.cache.delete([self.id, 'indirect_reports_ids'])
    Rails.cache.delete([self.id, 'role_name'])
    self.profile.flush_cache if self.profile
    Rails.cache.delete([self.id, 'employee_type'])
    true
  end

  def validate_emails
    validate_email(email, "email")
    validate_email(personal_email, "personal_email")
  end

  def validate_onboarding_profile_template
    if self.onboarding_profile_template
      errors.add(:base, "Invalid Profile Template Process Type") if onboarding_profile_template.process_type.name != "Onboarding"
    end
  end

  def validate_offboarding_profile_template
    if self.offboarding_profile_template
      errors.add(:base, "Invalid Profile Template Process Type") if offboarding_profile_template.process_type.name != "Offboarding"
    end
  end

  def validate_email(email, email_type)
    return unless email.present?

    user = User.with_deleted.where('email = :email OR personal_email = :email', email: email)
    user = user.where(company_id: self.company_id) if self.company && email_type == 'personal_email'
    update_user = user.exists? && user.first.id.eql?(id)
    if !update_user && user.exists?
      errors.delete(:email) if errors.messages[:email].present? && email_type.eql?('personal_email')
      errors.add(:base, I18n.t('admin.people.create_profile.duplicate_email_message', email: email))
    end
    errors[:base].uniq!
  end

  def self.trigger_algolia_worker(record, remove)
    if record.super_user == false && record.current_stage != 'incomplete'
      if remove
        AlgoliaWorker.perform_now(record.id, nil, remove)
      else
        AlgoliaWorker.new.perform(record.id, record, remove)
      end
    end
  end

  def self.current
    RequestStore.store[:user]
  end

  def self.current=(user)
    RequestStore.store[:user] = user
  end

  def self.clear_current_user
    RequestStore.clear!
  end

  def remove_from_algolia
    User.trigger_algolia_worker(self, true)
  end

  def is_on_leave?
    return nil unless self.company.enabled_time_off
    date = self.company.time.to_date
    request = self.pto_requests.where("pto_requests.user_id = :user_id AND pto_requests.status = 1 AND pto_requests.begin_date <= :date AND ((pto_requests.partial_day_included = true AND pto_requests.end_date >= :date) OR (pto_requests.partial_day_included = false AND pto_requests.end_date >= :date))",
                                      date: date, user_id: self.id).order(:end_date).last
    return nil if request.nil?
    return_day = Pto::GetReturnDayOfUser.new.perform(request)
    return_day.is_a?(TrueClass) ? true : return_day&.strftime("%m/%d/%y")
  end

  def is_finishing_preboarding?
    self.saved_change_to_current_stage? && (self.current_stage_before_last_save == 'preboarding' || self.current_stage_before_last_save == 'invited') && self.active? && (self.current_stage == 'pre_start' || self.current_stage == 'first_week' || self.current_stage == 'first_month' || self.current_stage == 'ramping_up' || self.current_stage == 'registered')
  end

  def onboarded?
    (self.if_pre_start? || self.if_first_week? || self.if_first_month? || self.if_ramping_up?) && self.onboarding?
  end

  def if_pre_start?
    self.start_date > Date.today && !self.termination_date if self.start_date.present?
  end

  def if_first_week?
    !if_pre_start? && (self.start_date + 7.days) > Date.today && !self.termination_date
  end

  def if_first_month?
    !if_pre_start? && !if_first_week? && (self.start_date + 30.days) > Date.today && !self.termination_date
  end

  def if_ramping_up?
    !(if_pre_start? || if_first_week? || if_first_month? || self.termination_date)
  end

  def if_registered?
    !(onboarding? || termination_date)
  end

  def if_active?
    !(if_pre_start? || if_first_week? || if_first_month? || if_ramping_up? || onboarding? || self.registered?)
  end

  def get_user_document_connections_urls(user_document_connection)
    urls = []
    user_document_connections = self.user_document_connections.where(id: user_document_connection, state: 'completed')
    user_document_connections.each do |user_document_connection|
      if user_document_connection.attached_files.present?
        user_document_connection.attached_files.each do |attached_file|
          urls << { url: attached_file.file.url, file_name: attached_file.original_filename }
        end
      end
    end
    urls
  end

  def initiate_notifications_after_onboarding(send_email_at = nil, profile_template_id = nil)
    Interactions::Users::ManagerBuddyEmail.new(self, self.manager, 'Manager', 'new_manager', send_email_at).perform if self.manager
    Interactions::Users::ManagerBuddyEmail.new(self, self.buddy, company.buddy, 'new_buddy', send_email_at).perform if self.buddy
    if send_email_at
      Okta::SendEmployeeToOktaJob.perform_at(send_email_at, self.id) if company.authentication_type == 'okta'
      SsoIntegrations::OneLogin::CreateOneLoginUserFromSaplingJob.perform_at(send_email_at, self.id) if company.authentication_type == 'one_login'
    else
      Okta::SendEmployeeToOktaJob.perform_async(self.id) if company.authentication_type == 'okta'
      SsoIntegrations::OneLogin::CreateOneLoginUserFromSaplingJob.perform_async(self.id) if company.authentication_type == 'one_login'
    end
    task_ids = self.task_user_connections.pluck(:task_id)
    # Interactions::Activities::Assign.new(self, task_ids, nil, true).perform if task_ids.present?
    Interactions::Users::NotifyManagerToProvideInformationEmail.new(self, self.manager, profile_template_id).perform if self.manager.present?
  end

  def if_last_month?
    self.termination_date && self.termination_date >= (Date.today + 1.week) && self.termination_date < (Date.today + 1.month)
  end

  def if_last_week?
    self.termination_date && !if_last_month? && self.termination_date >= Date.today && self.termination_date < (Date.today + 1.week)
  end

  def if_offboarding?
    self.termination_date && self.termination_date >= Date.today && !if_last_month? && !if_last_week?
  end

  def if_departed?
    termination_date && Date.today > termination_date
  end

  aasm(:stage, column: :current_stage, enum: true, whiny_transitions: false) do
    state :incomplete, initial: true
    state :invited
    state :preboarding
    state :pre_start
    state :first_week
    state :first_month
    state :ramping_up
    state :registered
    state :offboarding
    state :last_month
    state :last_week
    state :departed

    event :invite do
      transitions from: :incomplete, to: :invited
    end

    event :rehire do
      transitions from: :departed, to: :invited
    end

    event :preboarding do
      transitions from: :invited, to: :preboarding
      transitions from: :registered, to: :preboarding
    end

    event :onboarding do
      transitions from: [:first_week, :first_month, :ramping_up], to: :pre_start, guards: [:onboarding?, :if_pre_start?]
      transitions from: [:pre_start, :first_month, :ramping_up], to: :first_week, guards: [:onboarding?, :if_first_week?]
      transitions from: [:pre_start, :first_week, :ramping_up], to: :first_month, guards: [:onboarding?, :if_first_month?]
      transitions from: [:pre_start, :first_week, :first_month], to: :ramping_up, guards: [:onboarding?, :if_ramping_up?]
      transitions from: [:pre_start, :first_week, :first_month, :ramping_up], to: :registered, guards: :if_registered?
    end

    event :offboarding do
      transitions from: [:invited, :preboarding, :pre_start, :first_week, :first_month, :ramping_up, :registered, :last_month, :last_week, :departed], to: :offboarding, guard: :if_offboarding?
      transitions from: [:invited, :preboarding, :pre_start, :first_week, :first_month, :ramping_up, :registered, :offboarding, :last_week, :departed], to: :last_month, guard: :if_last_month?
      transitions from: [:invited, :preboarding, :pre_start, :first_week, :first_month, :ramping_up, :registered, :offboarding, :last_month, :departed], to: :last_week, guard: :if_last_week?
      transitions from: [:invited, :preboarding, :pre_start, :first_week, :first_month, :ramping_up, :registered, :offboarding, :last_month, :last_week], to: :departed, guard: :if_departed?
    end

    event :offboarded do
      transitions from: [:invited, :preboarding, :pre_start, :first_week, :first_month, :ramping_up, :registered, :offboarding, :last_month, :last_week, :departed], to: :departed, guard: :if_departed?
    end
  end

  aasm(:state, column: :state, whiny_transitions: false) do
    state :active, initial: true
    state :inactive

    event :activate do
      transitions from: :inactive, to: :active
    end

    event :deactivate do
      transitions from: :active, to: :inactive
    end
  end

  def stage_onboarding?
    onboarding = self.if_pre_start?
    onboarding ||= self.if_first_week?
    onboarding ||= self.if_first_month?
    onboarding || self.if_ramping_up?
  end

  def stage_departed?
    offboarding = self.current_stage == 'offboarding'
    offboarding ||= self.current_stage == 'last_week'
    offboarding ||= self.current_stage == 'last_month'
    offboarding || self.current_stage == 'departed'
  end

  def stage_registered?
    registered = self.current_stage == 'pre_start'
    registered ||= self.current_stage == 'first_week'
    registered ||= self.current_stage == 'first_month'
    registered ||= self.current_stage == 'ramping_up'
    registered ||= self.current_stage == 'registered'

    self.state == 'active' && registered
  end

  def stage_offboarding?
    offboarding = self.current_stage == 'offboarding'
    offboarding ||= self.current_stage == 'last_week'
    offboarding ||= self.current_stage == 'last_month'

    self.state == 'active' && offboarding
  end

  def remove_information_on_inactive
    self.pending_hire.update(state: 'inactive') if self.pending_hire
    self.company.users.where(id: self.all_managed_users.pluck(:id)).update_all(manager_id: nil)
    self.company.users.where(id: self.buddy_users.pluck(:id)).update_all(buddy_id: nil)
    self.custom_field_coworker.destroy_all
    self.expire_cache
  end

  def inactive_user
    self.deactivate!
    enforce_general_data_protection_regulation_on_termination_date_change(self) if !self.is_gdpr_action_taken.present? && self.termination_date.present? && self.departed?
  end

  def inactive_user_on_departed
    create_webhook_events
    inactive_user
  end

  def active_user
    self.activate!
  end

  def restore_information_on_active
    self.pending_hire.update(state: 'active') if self.pending_hire
  end

  def update_current_stage_on_start_date_change
    @is_current_stage_changed = true
    self.onboarding!
  end

  def update_current_stage_on_termination_date_change
    @is_current_stage_changed = true
    self.offboarding!
  end

  def user_documents_count
    self.user_document_connections.count + self.assigned_paperwork_requests.count + self.paperwork_requests_to_co_sign.count
  end

  def total_document_count
    User.incomplete_documents_count_with_request(self.id) + self.assigned_paperwork_requests.count + self.paperwork_requests_to_co_sign.count
  end

  def user_tasks_count
    self.task_user_connections.where.not(task_id: nil).count
  end

  def current_state_changed?
    self.saved_change_to_state? && (self.invited? || self.registered? || self.pre_start? || self.first_week? || self.first_month? || self.ramping_up? || self.offboarding? || self.departed?) && self.active?
  end

  def counter_changed?
    record = self
    (record.saved_change_to_outstanding_tasks_count? && record.outstanding_tasks_count < 0) ||
      (record.saved_change_to_outstanding_owner_tasks_count? && record.outstanding_owner_tasks_count < 0) ||
      (record.saved_change_to_incomplete_upload_request_count? && record.incomplete_upload_request_count < 0) ||
      (record.saved_change_to_incomplete_paperwork_count? && record.incomplete_paperwork_count < 0) ||
      (record.saved_change_to_co_signer_paperwork_count? && record.co_signer_paperwork_count < 0)
  end

  def current_state_or_counter_changed?
    current_state_changed? || counter_changed?
  end

  def initialize_preboarding_progress
    self.preboarding_progress = {
      welcome: false,
      our_story: false,
      our_people: false,
      about_you: false,
      wrapup: false
    }
  end

  def update_comments_description_for_mentioned_users
    update_comments_description(self)
  end

  def enable_document_notification
    self.update(document_seen: false)
  end

  def create_active_pending_hire
    PendingHire.create(
      { first_name: self.first_name, last_name: self.last_name, team_id: self.team_id, location_id: self.location_id,
        manager_id: self.manager_id, start_date: self.start_date, title: self.title, company_id: self.company_id, personal_email: (self.email || self.personal_email),
        duplication_type: PendingHire.duplication_types[:active], user_id: self.id }
    )
  end

  def people_validate?
    self.super_user == false && self.stage_registered? && self.start_date <= Date.today
  end

  def algolia_attributes_changed?
    if (self.saved_change_to_start_date? || self.saved_change_to_current_stage? || self.saved_change_to_state? || self.saved_change_to_first_name? ||
      self.saved_change_to_last_name? || self.saved_change_to_title? || self.saved_change_to_team_id? || self.saved_change_to_location_id? || self.saved_change_to_preferred_name?)
      User.trigger_algolia_worker(self, false)
    end
  end

  def restore_on_algolia
    User.trigger_algolia_worker(self, false)
  end

  def full_name
    [self.first_name, self.last_name].compact.reject(&:blank?) * ' '
  end

  def create_profile
    self.build_profile.save!
  end

  def update_preferred_full_name
    initial_name = self.first_name
    initial_name = self.preferred_name if self.preferred_name.present? && self.preferred_name.length > 0
    self.preferred_full_name = "#{initial_name} #{self.last_name}"
    self.preferred_name = nil if self.preferred_name == ""
  end

  def initials
    initial_name = self.preferred_name.present? ? self.preferred_name : self.first_name
    "#{initial_name.first.capitalize} #{self.last_name.first.capitalize}"
  end

  def employee?
    role == "employee"
  end

  def onboarding_finished
    if !self.onboarding?
      begin
        self.update_column(:onboarding_completed, true)

        SlackNotificationJob.perform_later(self.company_id, {
          username: self.full_name,
          text: I18n.t("slack_notifications.admin_user.onboarding", full_name: self.full_name)
        })
        History.create_history({
                                 company: self.company,
                                 user_id: self.id,
                                 description: I18n.t("history_notifications.admin_user.onboarding", full_name: self.full_name),
                                 attached_users: [self.id]
                               })
      rescue Exception => e
      end
    end
  end

  def update_manager_activites_over_the_night
    Users::ReassignManagerActivitiesJob.perform_async(self.company_id, self.id, self.manager_id_before_last_save) if self.id && self.manager_id_before_last_save
  end

  def preboarding_finished
    PushEventJob.perform_later('preboarding-finished', self, {
      employee_id: self.id,
      employee_name: self.full_name,
      employee_email: self.email
    })

    begin
      SlackNotificationJob.perform_later(self.company_id, {
        username: self.full_name,
        text: I18n.t("slack_notifications.admin_user.preboarding", full_name: self.full_name)
      })
      History.create_history({
                               company: self.company,
                               user_id: self.id,
                               description: I18n.t("history_notifications.admin_user.preboarding", full_name: self.full_name),
                               attached_users: [self.id]
                             })
    rescue Exception => e
    end
    add_employee_to_bamboo() if self.company.integration_types.include?('bamboo_hr')
    PreboardingCompleteEmailJob.perform_later(self.id) if self.email_enabled? && self.is_preboarding_to_registerd_stage?

    add_employee_to_integrations
    create_integration_profiles

    @is_current_stage_changed = true

    previous_stage = self.current_stage_before_last_save
    if self.onboarding!
      WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'stage_completed', type: 'stage_completed', stage: previous_stage, triggered_for: id, triggered_by: User.current.try(:id) })
      WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'stage_started', type: 'stage_started', stage: self.current_stage_before_last_save, triggered_for: id, triggered_by: User.current.try(:id) })
    end
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'onboarding', type: 'onboarding', stage: 'completed', triggered_for: id, triggered_by: User.current.try(:id), user_id: self.id })
  end

  def offboard_user(task_ids = nil)
    return true unless self.termination_date.present?
    OffboardingTasksJob.perform_async(self.id, task_ids) if task_ids && self.email_enabled?
    case self.remove_access_timing
    when "remove_immediately"
      remove_access
    when "default"
      termination_time = (self.termination_date + 1.day).to_time.change({hour: 1, offset: "UTC" })
      if Time.now.utc > termination_time.utc
        remove_access
      elsif (termination_date && (Date.today < (termination_date + 1.day)))
        self.update_attribute(:state, "active") if self.state == "inactive"
        self.offboarding!
      end
    when "custom_date"
      if current_time_zone >= get_remove_access_termination_time
        remove_access
      else
        self.update_attribute(:state, "active") if self.state == "inactive"

        self.offboarding!
      end
    end
    true
  end

  def get_remove_access_termination_time
    self.remove_access_date.to_time.change({ hour: self.remove_access_time }).asctime.in_time_zone(self.remove_access_timezone)
  end

  def is_access_removed?
    Time.now > self.get_remove_access_termination_time rescue true
  end

  def picture
    if self.profile_image.present? && self.profile_image.file_url.present?
      path = self.profile_image.file_url :thumb
      if Rails.env == "development"
        "http://#{self.company.domain}:3000#{path}"
      elsif Rails.env == "test"
        "http://#{self.company.domain}:3001#{path}"
      else
        is_url_valid?(path) ? path : "https://#{self.company.domain}/#{path}"

      end
    else
      nil
    end
  end

  def medium_picture
    if profile_image.present? && profile_image.file.present?
      profile_image.file_url :medium
    else
      nil
    end
  end

  def original_picture
    if profile_image.present? && profile_image.file.present?
      profile_image.file_url
    else
      nil
    end
  end

  def onboarding?
    self.outstanding_tasks_count > 0 || (self.incomplete_upload_request_count + self.incomplete_paperwork_count) > 0 || (self.start_date.present? && self.start_date > Sapling::Application::ONBOARDING_DAYS_AGO)
  end

  def fix_counters
    Interactions::Users::FixUserCounters.new(self, true).perform
  end

  def add_employee_to_integrations
    add_employee_to_adp_workforce_now() if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| self.company.integration_types.include?(api_name) }.present?
  end

  def add_employee_to_bamboo
    if !self.bamboo_id.present?
      ::HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob.set(wait: 5.minutes).perform_later(self.id, true)
    end
  end

  def add_employee_to_adp_workforce_now
    create_adp_profile(self.id)
  end

  def notify_account_creator_about_manager_form_completion
    self.try(:manager).update(manager_form_token: nil) if self.try(:manager).present? && self.manager.active_managed_users.find_by(is_form_completed_by_manager: User.is_form_completed_by_managers[:incompleted]).nil?
    Interactions::Users::NotifyAccountCreatorAboutManagerFormCompletionEmail.new(self, self.manager, self.account_creator).perform if self.account_creator && self.email_enabled?
  end

  def notify_user_about_change_in_start_date
    self.old_start_date = start_date_before_last_save
    UserMailer.start_date_change_email(self).deliver_now! if self.company.start_date_change_emails? && !['departed', 'incomplete'].include?(self.current_stage)
  end

  def after_create_manager_email
    manager_email(true)
  end

  def manager_email(send_without_checks = false)
    if send_without_checks || (self.email_enabled? && self.current_stage != 'incomplete' && !self.incomplete? && !self.departed? && self.active? && self.manager_id && self.manager.present?)
      ManagerBuddyEmailJob.perform_async(self.id, true, self.manager.id)
    end
  end

  def buddy_email
    ManagerBuddyEmailJob.perform_async(self.id, false, self.buddy.id) if self.email_enabled? && self.current_stage != 'incomplete'
  end

  def email_enabled?
    !(self.updated_from.present? && self.updated_from == 'integration')
  end

  def lock_user
    if !self.access_locked? && self.failed_attempts == 3 && (self.role == 'admin' || self.role == 'account_owner')
      self.lock_access!
    end
  end

  #One option from 'to_map or sub_field_name' works at a time, to_map gets priority if true
  #set field directly by sending field variable
  def get_custom_field_value_text(field_name, to_map = false, sub_field_name = nil, field = nil, only_id = false, custom_field_id = nil, only_guid = false,
                                  pipe_format = false, is_workday = false, is_adp = false, adp_enviornment = 'US', gsuite_mapping = false, disable_international_phone_apostrophe = false, is_paylocity = false, is_profile_template_flag = false)
    return unless self.onboarding_profile_template.profile_template_custom_field_connections.joins(:custom_field).where(custom_fields: { name: field_name }).present? if (self.company.sync_template_fields_feature_flag && is_profile_template_flag && self.onboarding_profile_template)

    if field
      custom_field = field
    elsif custom_field_id.present?
      custom_field = self.company.custom_fields.find_by(id: custom_field_id)
    else
      custom_field = self.company.custom_fields.where('name ILIKE ?', field_name).first
    end
    field_name = custom_field.try(:name)
    ret_val = nil
    return nil if !custom_field
    begin
      if !CustomField.typehHasSubFields(custom_field.field_type)
        field = self.custom_field_values.joins(:custom_field).where(custom_fields: { name: field_name, id: custom_field.id }).first
        if field
          if (custom_field.field_type == 'mcq' || custom_field.field_type == 'employment_status') && field.custom_field_option
            if is_workday.present?
              ret_val = field.custom_field_option.workday_wid
            elsif is_adp.present?
              if adp_enviornment == 'US'
                ret_val = field.custom_field_option.adp_wfn_us_code_value
              elsif adp_enviornment == 'CAN'
                ret_val = field.custom_field_option.adp_wfn_can_code_value
              end
            elsif gsuite_mapping.present?
              ret_val = field.custom_field_option.gsuite_mapping_key
            elsif is_paylocity.present?
              ret_val = field.custom_field_option.paylocity_group_id
            else
              ret_val = only_id.present? ? field.custom_field_option.id : field.custom_field_option.option
            end
          elsif custom_field.field_type == 'multi_select' && field.checkbox_values
            if gsuite_mapping.present?
              ret_val = custom_field.custom_field_options.where(id: field.checkbox_values).pluck(:gsuite_mapping_key)
            else
              if only_id.present?
                ret_val = custom_field.custom_field_options.where(id: field.checkbox_values).pluck(:id)
              else
                ret_val = custom_field.custom_field_options.where(id: field.checkbox_values).pluck(:option)
              end
            end
          elsif custom_field.field_type == 'coworker' && field.coworker
            if !only_guid
              ret_val = only_id.present? ? field.coworker.id : field.coworker.display_name
            else
              ret_val = field.coworker.try(:guid)
            end
          else
            if field.value_text
              if custom_field.field_type == "date"
                ret_val = field.value_text.to_date.to_s rescue nil
                ret_val = Date.strptime(field.value_text, '%m/%d/%Y').to_s rescue nil if ret_val.blank?
              else
                ret_val = field.value_text
              end
            end
          end
        end
      else
        scf_ids = custom_field.sub_custom_fields.pluck(:id)
        if scf_ids && scf_ids.length > 0
          cfvs = self.custom_field_values.where(sub_custom_field_id: scf_ids)

          if custom_field.field_type == "address"
            line1 = nil
            line2 = nil
            city = nil
            zip = nil
            state = nil
            country = nil

            cfvs.each do |cfv|
              case cfv.sub_custom_field.name
              when 'Line 1'
                line1 = cfv.value_text
              when 'Line 2'
                line2 = cfv.value_text
              when 'City'
                city = cfv.value_text
              when 'State'
                state = cfv.value_text
              when 'Country'
                country = cfv.value_text
              when 'Zip'
                zip = cfv.value_text
              end
            end

            city = nil if is_city_not_required(country)

            if sub_field_name
              ret_val = zip if sub_field_name == 'Zip'
              ret_val = city if sub_field_name == 'City'
              ret_val = country if sub_field_name == 'Country'
              ret_val = state if sub_field_name == 'State'
              ret_val = line1 if sub_field_name == 'Line 1'
              ret_val = line2 if sub_field_name == 'Line 2'
            else
              ret_val = {line1: line1, line2: line2, city: city, state: state, country: country, zip: zip}
            end
          elsif custom_field.field_type == "currency"
            currency_type = ''
            currency_value = ''
            cfvs.each do |cfv|
              case cfv.sub_custom_field.name
              when 'Currency Type'
                currency_type = cfv.value_text
              when 'Currency Value'
                currency_value = cfv.value_text
              end
            end
            if to_map
              ret_val = { currency_type: currency_type, currency_value: currency_value }
            elsif pipe_format.present?
              ret_val = (currency_type.present? && currency_value.present?) ? (currency_type.to_s + "|" + currency_value.to_s) : nil
            elsif sub_field_name
              ret_val = currency_type if sub_field_name == 'Currency Type'
              ret_val = currency_value if sub_field_name == 'Currency Value'
            else
              currency_field_value = ""
              if currency_type.present? && currency_value.present?
                currency_field_value = currency_type + ',' + currency_value
              elsif currency_type.blank? && currency_value.present?
                currency_field_value = currency_value
              else
                currency_field_value = ''
              end
              ret_val = currency_field_value
            end
          elsif custom_field.field_type == "tax"
            tax_type = ''
            tax_value = ''

            cfvs.each do |cfv|
              case cfv.sub_custom_field.name
              when 'Tax Type'
                tax_type = cfv.value_text
              when 'Tax Value'
                tax_value = cfv.value_text
              end
            end

            if to_map
              ret_val = { tax_type: tax_type, tax_value: tax_value }
            elsif pipe_format.present?
              ret_val = (tax_type.present? && tax_value.present?) ? (tax_type.to_s + "|" + tax_value.to_s) : nil
            elsif sub_field_name
              ret_val = tax_type if sub_field_name == 'Tax Type'
              ret_val = tax_value if sub_field_name == 'Tax Value'
            else
              tax_field_value = ''

              if tax_type.present? && tax_value.present?
                tax_field_value = tax_type + ',' + tax_value
              else
                tax_field_value = tax_type.present? ? tax_type : (tax_value.present? ? tax_value : '')
              end
              ret_val = tax_field_value
            end
          elsif custom_field.field_type == "phone"
            country = nil
            area = nil
            phone = nil

            cfvs.each do |cfv|
              case cfv.sub_custom_field.name
              when 'Country'
                country = cfv.value_text
              when 'Area code'
                area = cfv.value_text
              when 'Phone'
                phone = cfv.value_text
              end
            end

            if to_map
              ret_val = { country: country, area_code: area, phone: phone }
            elsif pipe_format.present?
              ret_val = (country.present? && (area.present? || phone.present?)) ? (country.to_s + '|' + area.to_s + '|' + phone.to_s) : nil
            elsif sub_field_name
              ret_val = ISO3166::Country.find_country_by_alpha3(country)&.country_code if sub_field_name == 'Country'
              ret_val = area if sub_field_name == 'Area code'
              ret_val = phone if sub_field_name == 'Phone'
            else
              phone_number = ''
              country_code = ''
              if country
                country_code = ISO3166::Country.find_country_by_alpha3(country)&.country_code
              end
              if disable_international_phone_apostrophe
                phone_number += country_code unless country_code.blank?
              else
                phone_number += "'" + '+' + country_code unless country_code.blank?
              end
              phone_number += ' ' + area if area
              phone_number += ' ' + phone if phone

              ret_val = phone_number if phone_number.length > 0
            end
          elsif custom_field.national_identifier?
            id_number, id_country, id_type = '', '', ''

            cfvs.each do |cfv|
              case cfv.sub_custom_field.name
              when 'ID Country'
                id_country = cfv.value_text
              when 'ID Type'
                id_type = cfv.value_text
              when 'ID Number'
                id_number = cfv.value_text
              end
            end

            if to_map
              ret_val = { id_country: id_country, id_type: id_type, id_number: id_number }
            elsif pipe_format
              ret_val = [id_country, id_type, id_number].join('|')
            elsif sub_field_name
              ret_val = { 'ID Country' => id_country, 'ID Type' => id_type, 'ID Number' => id_number }[sub_field_name]
            else
              ret_val = [id_country, id_type, id_number].join(',')
            end
          end
        end
      end
    rescue Exception => e
      ret_val = nil
    end
    ret_val
  end

  def get_custom_field_value_workday_wid(field_name)
    get_custom_field_value_text(field_name, false, nil, nil, false, nil, false, false, true)
  end

  def get_custom_field_value_adp_code(field_name, environment, is_profile_template_flag = true)
    get_custom_field_value_text(field_name, false, nil, nil, false, nil, false, false, false, true, environment, false, false, false, is_profile_template_flag)
  end

  def get_custom_field_value_text_by_profile_template_check(field_name, to_map = false, is_profile_template_flag = true)
    get_custom_field_value_text(field_name, to_map, nil, nil, false, nil, false, false, false, false, 'US', false, false, false, is_profile_template_flag)
  end

  def is_preboarding_to_registerd_stage?
    state_changed = false
    onboarded_stages = ['pre_start', 'first_week', 'first_month', 'ramping_up', 'registered']
    if self.saved_changes.key?("current_stage")
      previous_value = self.saved_changes['current_stage'].first
      new_value = self.saved_changes['current_stage'].last
      state_changed = ((previous_value == 'invited' || previous_value == 'preboarding') and (onboarded_stages.include? new_value))
    end
    state_changed
  end

  def self.from_saml_response(auth_response, current_company)
    where("company_id = ? and lower(email) =  ?", current_company.id, auth_response.nameid.downcase).first
  end

  def self.get_from_employee_number_and_email emp_number, email, current_company
    response = nil
    user_obj_array = current_company.users.where("lower(email) = ? or lower(personal_email) = ?", email.downcase, email.downcase)
    if user_obj_array.size > 1
      response = I18n.t('errors.multiple_user_with_mail')
    elsif user_obj_array.size == 0
      response = I18n.t('errors.user_not_found_email')
    else
      employee_number = user_obj_array.first.get_custom_field_value_text("Employee Number")
      employee_number == emp_number ? response = user_obj_array.first : response = self.errors.add(:base, I18n.t('errors.user_not_found_number'))
    end
    response
  end

  def get_users_managed_by_admin
    return if self.role != 'admin'
    users = User.where(state: 'active').where(company_id: self.company_id).includes(:team, :location)
    user_role = self.user_role
    users = users.where(team: user_role.team_permission_level) if user_role.team_permission_level.present? && user_role.team_permission_level[0] != "all"
    users = users.where(location: user_role.location_permission_level) if user_role.location_permission_level.present? && user_role.location_permission_level[0] != "all"
    if user_role.status_permission_level[0] != 'all'
      users = users.select { |u| user_role.status_permission_level.include?(u.employee_type) }
    end
    users.map(&:id)
  end

  def get_present_email
    self.email.present? ? self.email : self.personal_email
  end

  def get_google_auth_credential_id
    "#{self.company.name}-#{self.id}-#{get_present_email}"
  end

  def suspend_gsuite_account
    if !self.gsuite_account_deprovisioned
      company = self.company
      gs_obj = Gsuite::ManageAccount.new
      gs_obj.delete_gsuite_account(self)
    end
  end

  def send_provising_credentials
    company = self.company
    send_now = false
    if self.send_credentials_type == "immediately"
      send_now = true
    elsif ["on", "before"].include?(self.send_credentials_type)
      # If start date has passed, send immediately
      is_past = self.start_date < Date.today
      is_earlier_today = self.start_date == Date.today && (ActiveSupport::TimeZone[self.send_credentials_timezone].utc_offset / (60 * 60) + self.send_credentials_time >= Time.now.utc.hour)
      if is_past || is_earlier_today
        send_now = true
      else
        # Otherwise, schedule to send on start date AT specified time IN specified timezone
        sd = self.start_date
        utc_hour = self.send_credentials_time - ActiveSupport::TimeZone[self.send_credentials_timezone].utc_offset / (60 * 60)

        if utc_hour < 0
          sd = sd - 1.day
          utc_hour += 24
        elsif utc_hour >= 24
          sd = sd + 1.day
          utc_hour = utc_hour % 24
        end

        time = Time.clone
        time.zone = self.send_credentials_timezone
        is_dst = time.zone.parse(self.start_date.to_s).dst?

        sending_time = DateTime.new(sd.year, sd.month, sd.day, utc_hour, 0, 0, "utc")
        send_credentials_at = is_dst.present? ? (sending_time - 1.hour) : sending_time
        send_credentials_at -= self.send_credentials_offset_before.days if self.send_credentials_type == "before"

        if send_credentials_at <= DateTime.now
          send_now = true
        else
          SendGsuiteCredentialsJob.perform_at(send_credentials_at, self.id, company.id) if company.provisioning_integration_type == 'gsuite'
          SendAdfsCredentialsJob.perform_at(send_credentials_at, self.id, company.id) if company.provisioning_integration_type == 'adfs_productivity'
        end
      end
    end
    if send_now
      if company.provisioning_integration_type == 'gsuite'
        UserMailer.notify_user_about_gsuite_account_creation(self.id, company).deliver_later(wait_until: 5.seconds.from_now)
        self.update_column(:google_account_credentials_sent, true)
      elsif company.provisioning_integration_type == 'adfs_productivity'
        UserMailer.notify_user_about_adfs_account_creation(self.id, company).deliver_later(wait_until: 5.seconds.from_now)
        self.update_column(:adfs_account_credentials_sent, true)
      end
    end
  end

  def get_anniversary_date(start_date, end_date)
    return nil if self.start_date.nil? || (self.start_date + 5.months) > end_date
    current_year_date = Time.new(start_date.strftime("%Y").to_i, self.start_date.to_date.strftime("%m").to_i, self.start_date.to_date.strftime("%d").to_i).to_date
    current_year_date += 1.years if current_year_date.present? && current_year_date < Time.now.in_time_zone(company.time_zone).to_date
    first_aniversary_date = self.start_date + 6.months

    if (start_date .. end_date).include?(first_aniversary_date.to_date)
      return { date: first_aniversary_date.to_date.strftime("%B %-d"), title: I18n.t("admin.calendar_event.content.six_month_anniversary") }
    elsif (start_date .. end_date).include?(current_year_date.to_date) && self.start_date.strftime("%Y") != end_date.strftime("%Y")
      title = (current_year_date.strftime("%Y").to_i - self.start_date.strftime("%Y").to_i).to_s + ' year(s)'
      return { date: self.start_date.strftime("%B %-d"), title: title }
    else
      return nil
    end
  end

  def get_birthday_date(start_date, end_date)
    dob = self.get_custom_field_value_text('Date Of Birth')
    current_year_date = Time.new(start_date.strftime("%Y").to_i, dob.to_date.strftime("%m").to_i, dob.to_date.strftime("%d").to_i).to_date if dob.present?
    current_year_date += 1.years if current_year_date.present? && current_year_date < Time.now.in_time_zone(company.time_zone).to_date
    if dob.present? && (start_date .. end_date).include?(current_year_date.to_date)
      return dob.to_date.strftime("%B %-d")
    end
    return nil
  end

  def free_manager_role
    manager = self.manager
    if manager.present? && manager.all_managed_users.length == 1
      if manager.user_role.manager?
        manager.set_employee_role
      else
        manager.flush_managed_user_count manager.id
      end
    end
  end

  def set_employee_role
    self.flush_managed_user_count self.id
    employee_role = self.company.user_roles.where(role_type: UserRole.role_types[:employee], is_default: true).first rescue nil
    if employee_role.present?
      self.update_columns(role: 0, user_role_id: employee_role.id)
      self.flush_cached_role_name
    end
  end

  def update_admin_role
    if self.role == 'admin'
      role = self.company.user_roles.where(role_type: UserRole.role_types[:admin], is_default: true).first
      self.update_column(:user_role_id, role.id) if role.present?
    elsif self.role == 'employee'
      employee_role = self.company.user_roles.where(role_type: UserRole.role_types[:employee], is_default: true).first
      manager_role = self.company.user_roles.where(role_type: UserRole.role_types[:manager], is_default: true).first
      if self.managed_users.count > 0
        self.update_column(:user_role_id, manager_role.id) if manager_role.present?
      else
        self.update_column(:user_role_id, employee_role.id) if employee_role.present?
      end
    elsif self.role == 'account_owner' && !self.expires_in
      role = self.company.user_roles.where(role_type: UserRole.role_types[:super_admin], is_default: true).where.not(name: 'Ghost Admin').first
      self.update_column(:user_role_id, role.id) if role.present?
    end
    self.flush_cached_role_name
  end

  def update_user_role
    if self.user_role_id
      if self.user_role.role_type == 'super_admin'
        self.update_column(:role, 2) if self.role != 'account_owner'
      elsif self.user_role.role_type == 'admin'
        self.update_column(:role, 1) if self.role != 'admin'
      else
        self.update_column(:role, 0) if self.role != 'employee'
      end
    else
      if self.managed_users.count > 0
        role = self.company.user_roles.where(role_type: UserRole.role_types[:manager], is_default: true).first
      else
        role = self.company.user_roles.where(role_type: UserRole.role_types[:employee], is_default: true).first
      end
      update_columns(role: 0, user_role_id: role.id)
    end
    self.flush_cached_role_name
  end

  def assign_manager_role
    user = User.find(self.manager_id) if self.manager_id.present?
    if user && (user.user_role_id == nil || user.user_role.role_type == 'employee')
      manager_role = user.company.user_roles.where(role_type: UserRole.role_types[:manager], is_default: true).first rescue nil
      user.update_column(:user_role_id, manager_role.id) if manager_role.present?
      user.flush_cached_role_name
    end
  end

  def logout_user
    self.update_column(:tokens, {})
  end

  def destroy_pre_start_email_jobs
    DestroyPreStartEmailJob.perform_later(self.id)
  end

  def run_create_organization_chart_job
    if self.company.enabled_org_chart.present?
      self.company.run_create_organization_chart_job
    end
  end

  def run_update_organization_chart_job(options = { calculate_custom_groups: false, calculate_team_and_location: true })
    if self.company.enabled_org_chart.present?
      self.company.run_update_organization_chart_job(self.id, options)
    end
  end

  def self.get_organization_tree(company)
    company_updated = Company.find(company.id)
    if company_updated.organization_root
      unless company_updated.organization_chart.blank?
        company_updated.organization_chart.chart
      else
        company_updated.generate_organization_tree(true)
      end
    else
      nil
    end
  end

  def self.find_parents_ids(user)
    array_of_ids = []
    array_of_ids_check = []
    self.find_user_parent_ids(user, array_of_ids, array_of_ids_check)
    array_of_ids
  end

  def self.find_user_parent_ids(user, array_of_ids, array_of_ids_check)
    if !(user.present? && user.manager.present?)
      return
    end
    if array_of_ids_check.include?(user.manager.id)
      return
    end
    array_of_ids_check.push(user.manager.id)
    self.find_user_parent_ids(user.manager, array_of_ids, array_of_ids_check)
    array_of_ids.push(user.manager.id)
  end

  def get_object_name
    self.full_name
  end

  # Create default 10 or more anniversaries
  #TODO create future anniversaries check daily basis When some dates occors creat next year anniversary and if startdate change then need to update events
  def create_default_anniversaries
    return if self.super_user?
    self.calendar_events.with_deleted.where(event_type: 3).try(:each) { |e| e.really_destroy! }
    years_diff = TimeDifference.between(self.start_date, Date.today).in_years.to_i
    default_anniversaries_count = years_diff > 9 ? years_diff + 10 : 10
    default_anniversaries_count.times.each do |i|
      self.create_calendar_events_by i
    end
  end

  def get_next_yearly_anniversary_date start_date
    today = Date.today
    if today < start_date
      today = start_date
    end
    if today == start_date
      anniversary_date = start_date + 1.year
      return anniversary_date
    end
    years_worked = TimeDifference.between(start_date, today).in_years.to_i
    if today.month > start_date.month
      anniversary_date = start_date + (years_worked + 1).year
    elsif today.month == start_date.month
      anniversary_date = start_date + years_worked.year
      if today.day > start_date.day
        anniversary_date = start_date + (years_worked + 1).year
      elsif today.day == start_date.day
        anniversary_date = start_date + years_worked.year
      end
    else
      anniversary_date = start_date + (years_worked + 1).year
    end
    anniversary_date
  end

  def get_date_wrt_anniversary(event_type, numbers, days_or_weeks)
    date = self.start_date
    years = TimeDifference.between(self.start_date, Date.today).in_years.to_i
    if event_type == 'on'
      if (years == 0 || years == 1) && (self.start_date + 1.year) >= Date.today
        return self.start_date + 1.year
      else
        date = self.start_date + years.years
      end
    elsif event_type == 'before'
      if (years == 0 || years == 1) && (self.start_date + 1.year - eval(numbers.to_s + '.' + days_or_weeks)) >= Date.today
        return self.start_date + 1.year - eval(numbers.to_s + '.' + days_or_weeks)
      else
        date = self.start_date + years.years - eval(numbers.to_s + '.' + days_or_weeks)
      end
    elsif event_type == 'after'
      if (years == 0 || years == 1) && (self.start_date + 1.year + eval(numbers.to_s + '.' + days_or_weeks)) >= Date.today
        return self.start_date + 1.year + eval(numbers.to_s + '.' + days_or_weeks)
      else
        date = self.start_date + years.years + eval(numbers.to_s + '.' + days_or_weeks)
      end
    end
    return (date >= Date.today ? date : (date + 1.year))
  end

  def get_date_wrt_birthday(event_type, numbers, days_or_weeks)
    date = self.date_of_birth.try(:to_date)
    return nil unless date
    years = TimeDifference.between(date, Date.today).in_years.to_i
    date = date + years.years
    if event_type == 'before'
      date = (date - eval(numbers.to_s + '.' + days_or_weeks))
    elsif event_type == 'after'
      date = (date + eval(numbers.to_s + '.' + days_or_weeks))
    end
    return (date >= Date.today ? date : (date + 1.year))
  end

  def user_role_name
    (self.user_role && self.user_role.name != 'Super Admin' && self.user_role.is_default?) ? self.user_role.name + ' (default)' : self.user_role.try(:name)
  end

  def create_calendar_events_by year
    if year == 0
      event_date = self.start_date + 6.months
    else
      event_date = self.start_date + year.year
    end
    self.calendar_events.create(event_type: CalendarEvent.event_types["anniversary"], event_start_date: event_date, event_end_date: event_date, company_id: self.company_id)
  end

  def create_date_of_birth_calendar_event value_text
    date_of_birth = nil
    date_of_birth = Date.strptime(value_text, '%m/%d/%Y') rescue nil
    date_of_birth = value_text.to_date rescue nil if date_of_birth.blank?
    if date_of_birth.present?
      self.calendar_events.where(event_type: CalendarEvent.event_types[:birthday]).delete_all
      years_diff = TimeDifference.between(date_of_birth, Date.today).in_years.to_i
      years_diff = years_diff - 3
      6.times.each do |i|
        event_date = date_of_birth + (years_diff + i).year
        setup_calendar_event(self, 'birthday', self.company, event_date, event_date)
      end
    end
  end

  def date_of_birth
    cf = self.company.custom_fields.find_by(name: "Date of Birth") || self.company.custom_fields.find_by(name: "Birth Date")
    cfv = self.custom_field_values.find_by(custom_field_id: cf.id) if cf
    cfv = cfv.value_text if cfv
  end

  def update_assigned_policies(emp_status = nil, employment_status_was = nil, new_employment_status = nil)
    company = Company.find_by(id: self.company_id)
    return unless company && company.enabled_time_off
    if emp_status.nil?
      new_employment_status = self.get_employment_status
      # Remove pto policies
      # add new policies
      if self.saved_change_to_location_id? && self.saved_change_to_team_id?
        team_id_was = self.team_id_before_last_save
        new_team_id = self.team_id
        location_id_was = self.location_id_before_last_save
        new_location_id = self.location_id
        employment_status_was = self.get_employment_status
      elsif self.saved_change_to_location_id?
        team_id_was = new_team_id = self.team_id
        location_id_was = self.location_id_before_last_save
        new_location_id = self.location_id
        employment_status_was = self.get_employment_status
      elsif self.saved_change_to_team_id?
        location_id_was = new_location_id = self.location_id
        team_id_was = self.team_id_before_last_save
        employment_status_was = self.get_employment_status
        new_team_id = self.team_id
      else
        location_id_was = new_location_id = self.location_id
        team_id_was = new_team_id = self.team_id
      end
    else
      location_id_was = new_location_id = self.location_id
      team_id_was = new_team_id = self.team_id
    end
    existing_ids = self.assigned_pto_policies.pluck(:pto_policy_id)
    old_filters = set_fetching_policies_filters(team_id_was, location_id_was, employment_status_was)
    new_filters = set_fetching_policies_filters(new_team_id, new_location_id, new_employment_status)
    removed_pto_policies_ids = company.pto_policies.get_policies_by_location(old_filters[:filter_by_team], old_filters[:filter_by_location], old_filters[:filter_by_employment_status]).ids
    removed_pto_policies_ids = existing_ids & removed_pto_policies_ids
    assigned_pto_policies_ids = company.pto_policies.get_policies_by_location(new_filters[:filter_by_team], new_filters[:filter_by_location], new_filters[:filter_by_employment_status]).ids
    removed_policies = removed_pto_policies_ids - assigned_pto_policies_ids
    assigne_new_policies = assigned_pto_policies_ids - removed_pto_policies_ids
    self.assigned_pto_policies.where(pto_policy_id: removed_policies).destroy_all
    asigned_policies assigne_new_policies
    TimeOff::UpdatePtoRequestsBalanceByUser.perform_at(5.seconds.from_now, self.id)
  end

  def get_employment_status
    self.employee_type_field_option.try(:id)
  end

  def get_employment_status_option
    self.employee_type_field_option.try(:option)
  end

  def user_has_documents?
    self.paperwork_requests.where.not(state: 'draft').length > 0 || self.user_document_connections.length > 0 || self.personal_documents.length > 0 || self.paperwork_requests_to_co_sign.length > 0
  end

  def get_user_holidays
    self.company.holidays.where("(:status = ANY(status_permission_level) or :status_all = ANY(status_permission_level)) and (:team_all = ANY(team_permission_level) or :team = ANY(team_permission_level)) and (:all_location = ANY(location_permission_level) or :location = ANY(location_permission_level))", status: self.employee_type, status_all: "all", location: self.location_id.to_s, all_location: "all", team: self.team_id.to_s, team_all: "all")
  end

  def managed_users_working
    all_managed_users.where('last_day_worked >= ? OR last_day_worked IS NULL', Date.today).where(state: 'active').where('start_date <= ?', Date.today).where(current_stage: [3, 4, 5, 6, 11, 13, 14])
  end

  def cached_indirect_reports_ids
    Rails.cache.fetch([self.id, 'indirect_reports_ids'], expires_in: 1.days) do
      self.indirect_reports_ids
    end
  end

  def indirect_reports_ids
    result = []
    queue = [self]
    until queue.empty?
      manager_user = queue.pop
      manager_user.all_managed_users.each do |managed_user|
        unless result.include?(managed_user.id)
          queue.push(managed_user)
          result.push(managed_user.id)
        end
      end
    end
    result
  end

  def flush_cache
    if self.saved_change_to_title?
      unless self.title.nil?
        titles = Rails.cache.fetch("#{self.company_id}/job_titles")
        Rails.cache.delete("#{self.company_id}/job_titles") unless titles && titles.include?(self.title)
      end
    end
    if self.saved_change_to_current_stage? || self.saved_change_to_state? || self.saved_change_to_manager_id?
      self.flush_managed_user_count(self.manager_id_before_last_save, self.manager_id)
    end
    if self.saved_change_to_team_id?
      Team.expire_people_count(self.team_id) if self.team_id.present?
      Team.expire_people_count(self.team_id_before_last_save) if self.team_id_before_last_save.present?
    end
    if self.saved_change_to_location_id?
      Location.expire_people_count(self.location_id) if self.location_id.present?
      Location.expire_people_count(self.location_id_before_last_save) if self.location_id_before_last_save.present?
    end
    true
  end

  def flush_managed_user_count(old_manager_id, new_manager_id = nil)
    Rails.cache.delete([old_manager_id, 'managed_user_count']) if old_manager_id
    Rails.cache.delete([new_manager_id, 'managed_user_count']) if new_manager_id
    flush_manager_chain_cache(old_manager_id)
    flush_manager_chain_cache(new_manager_id)
    return true
  end

  def user_holidays
    self.company.holidays.where("('all' = ANY (team_permission_level) OR ? = ANY (team_permission_level)) OR ('all' = ANY (location_permission_level) OR ? = ANY (location_permission_level)) OR ('all' = ANY (status_permission_level) OR ? = ANY (status_permission_level))", self.team_id.to_s, self.location_id.to_s, self.employee_type)
  end

  def create_history_and_send_slack_message_on_invite
    begin
      if self.histories.where(created_by: History.created_bies[:system], email_type: History.email_types[:invite], event_type: History.event_types[:email]).length == 0
        SlackNotificationJob.perform_later(self.company_id, {
          username: self.full_name,
          text: I18n.t('slack_notifications.email.invite', full_name: self.full_name)
        })
        History.create_history({
                                 company: self.company,
                                 user_id: self.id,
                                 description: I18n.t('history_notifications.email.invite', full_name: self.full_name),
                                 attached_users: [self.id],
                                 created_by: History.created_bies[:system],
                                 event_type: History.event_types[:email],
                                 email_type: History.email_types[:invite]
                               })
      end
    rescue Exception => e
    end
  end

  def user_holidays_in_time_period start_date, end_date
    self.user_holidays.where("(begin_date = ? or begin_date >?) and (end_date = ? or end_date < ?)", start_date, start_date, end_date, end_date)
  end

  def anonymise_user_email
    unless self.destroyed?
      self.create_deleted_user_email(email: self.email, personal_email: self.personal_email)
      self.update_columns(email: (self.email + DateTime.now.to_s if self.email),
                          personal_email: (self.personal_email + DateTime.now.to_s if self.personal_email))
    end
  end

  def allowed_to_restore?
    archived_user_email = self.deleted_user_email
    if archived_user_email.present?
      emails = [archived_user_email.email, archived_user_email.personal_email]
      same_email_users = User.where('email IN (?) OR personal_email IN (?)', emails, emails)
      return same_email_users.blank?
    else
      return true
    end
  end

  def restore_user_email
    archived_user_email = self.deleted_user_email
    if archived_user_email
      self.update_columns(email: archived_user_email.email, personal_email: archived_user_email.personal_email)
      archived_user_email.destroy!
    end
  end

  def count_of_policies_not_assigned_to_user
    assinged_policies_id = self.assigned_pto_policies.pluck(:pto_policy_id)
    self.company.pto_policies.enabled.where.not(id: assinged_policies_id).size
  end

  def get_first_name
    self.preferred_name.present? ? self.preferred_name : self.first_name
  end

  def get_email
    self.email.present? ? self.email : self.personal_email
  end

  def user_is_ghost
    self.user_role&.name == "Ghost Admin"
  end

  def name_with_title
    self.title.present? ? self.preferred_full_name + " (#{self.title})" : self.preferred_full_name
  end

  def header_phone_number
    self.get_custom_field_value_text("Mobile Phone Number")
  end

  def update_termination_snapshot
    return if self.is_rehired
    snapshot = self.custom_table_user_snapshots.where(is_terminated: true).where.not(terminated_data: nil).last
    if snapshot.present?
      term_data = snapshot.terminated_data
      term_data["last_day_worked"] = self.last_day_worked
      snapshot.update_column(:terminated_data, term_data)
      snapshot.update_column(:effective_date, self.termination_date)
      date_column = snapshot.custom_snapshots.find_by(custom_field_id: snapshot.custom_table.custom_fields.find_by(name: "Effective Date").id)
      date_column.update_column(:custom_field_value, self.termination_date) if date_column.present?
    end
  end

  def update_task_due_dates
    if update_task_dates != false
      UpdateTaskDueDateJob.perform_later(id, false, true, nil, false)
    end
  end

  def key_date_changed key
    user_emails = self.user_emails.where('schedule_options @> ?', { relative_key: key }.to_json).where(email_status: 0)
    create_general_logging(self.company, 'Update scheduled Email', { result: "updating all scheduled emails #{user_emails.ids} for user id #{self.id} during key updating" })
    user_emails.try(:each) do |user_email|
      begin
        user_email.delete_scheduled
        user_email.invite_at = Inbox::SetInviteAt.new.set_invite_at(user_email)
        user_email.save!
        user_email.send_user_email
      rescue Exception => e
        create_general_logging(company, 'Error during updating scheduled email', { user_id: id,
                                                                                   user_email_id: user_email.id,
                                                                                   error: e.message })
      end
    end
  end

  def get_scheduled_email_count keys
    response = {}
    keys.each do |key|
      response.merge!("#{key}": self.user_emails.where('schedule_options @> ?', { relative_key: key }.to_json).where(email_status: UserEmail.statuses[:scheduled]).count)
    end

    response
  end

  def change_onboarding_profile_template(new_template_id, remove_existing_values = false)
    removed_field_ids = []
    new_template = self.company.profile_templates.find_by(id: new_template_id)
    if new_template.present?
      if remove_existing_values
        new_template_field_ids = new_template.custom_fields.pluck(:id)
        if self.onboarding_profile_template.present?
          fields_to_remove = self.onboarding_profile_template.custom_fields.where.not(id: new_template_field_ids).where.not(name: "Effective Date")
        else
          fields_to_remove = self.company.custom_fields.where.not(id: new_template_field_ids).where.not(name: "Effective Date")
        end
        sub_fields_to_remove = []
        fields_to_remove.each { |field| sub_fields_to_remove = sub_fields_to_remove.concat(field.sub_custom_fields) if field.sub_custom_fields.present? }
        self.custom_field_values.where("custom_field_id IN (?) OR sub_custom_field_id IN (?)", fields_to_remove.pluck(:id), sub_fields_to_remove.map { |field| field.id }).destroy_all
        removed_field_ids = fields_to_remove.pluck(:id)
        destroy_requested_field_value(removed_field_ids, 'false')
        CustomSnapshot.joins(:custom_table_user_snapshot).where(custom_table_user_snapshots: { user_id: self.id }).where(custom_field_id: removed_field_ids).update_all(custom_field_value: nil)
      end
      self.onboarding_profile_template_id = new_template.id
      unless new_template.profile_template_custom_field_connections.find_by(default_field_id: "abt").present?
        self.profile.update(about_you: nil)
        destroy_requested_field_value('about', 'true')
        removed_field_ids.push("abt")
      end
      unless new_template.profile_template_custom_field_connections.find_by(default_field_id: "lin").present?
        self.profile.update(linkedin: nil)
        destroy_requested_field_value('linkedin', 'true')
        removed_field_ids.push("lin")
      end
      unless new_template.profile_template_custom_field_connections.find_by(default_field_id: "twt").present?
        self.profile.update(twitter: nil)
        destroy_requested_field_value('twitter', 'true')
        removed_field_ids.push("twt")
      end
      unless new_template.profile_template_custom_field_connections.find_by(default_field_id: "gh").present?
        self.profile.update(github: nil)
        destroy_requested_field_value('github', 'true')
        removed_field_ids.push("gh")
      end
      unless new_template.profile_template_custom_field_connections.find_by(default_field_id: "bdy").present?
        self.buddy_id = nil
        destroy_requested_field_value('buddy', 'true')
        removed_field_ids.push("bdy")
      end
      self.save!
    end
    return removed_field_ids
  end

  def destroy_requested_field_value(field_id, is_default)
    CustomSectionApproval.destroy_requested_fields(field_id, is_default, nil, self.company, self.id)
  end

  def display_name
    self.company.global_display_name(self, self.company.display_name_format)
  end

  def display_first_name
    case self.company.display_name_format
    when 0, 1
      self.preferred_name || self.first_name
    when 2, 3
      self.first_name
    when 4
      self.last_name
    else
      self.preferred_name || self.first_name
    end
  end

  def fetch_email_templates(collection_params)
    collection_params = build_email_template_params(collection_params)
    collection_params.merge!(smart_assignment: self.smart_assignment)
    InboxEmailTemplatesCollection.new(collection_params)
  end

  def build_email_template_params(collection_params)
    collection_params.merge!(company_id: self.company_id)
    collection_params.merge!(include_all: true)
    if collection_params[:offboarding] || collection_params[:offboarding] == "true"
      collection_params = build_email_templates_offboarding_params(collection_params)
    else
      collection_params = build_email_templates_onboarding_params(collection_params)
    end

    collection_params
  end

  def build_email_templates_offboarding_params(collection_params)
    collection_params.merge!(offboarding: true)
    append_email_templates_LDE_to_params("Offboarding", collection_params)

    if collection_params[:smart_assignment_toggle] == "false"
      collection_params.delete("location_id")
      collection_params.delete("team_id")
      collection_params.delete("employment_status_id")
    end
    collection_params
  end

  def build_email_templates_onboarding_params(collection_params)
    if self.smart_assignment || collection_params['onboarding']
      append_email_templates_LDE_to_params("Onboarding", collection_params)
    end
    collection_params
  end

  def append_email_templates_LDE_to_params(process_type, collection_params)

    if process_type == 'Offboarding'
      if collection_params['send_by_email']
        template_LDE_filters(collection_params, self.employee_type_field_option&.id, self.location_id, self.team_id)
      else
        template_LDE_filters(collection_params, collection_params[:employment_status_id].to_i, collection_params[:location_id].to_i, collection_params[:team_id].to_i)
      end
    elsif process_type == 'Onboarding'
      template_LDE_filters(collection_params, self.employee_type_field_option&.id, self.location_id, self.team_id)
      collection_params = get_custom_group_values_for_onboarding_flow collection_params if self.company.smart_assignment_2_feature_flag
    end
  end

  def get_custom_group_values_for_onboarding_flow collection_params
    sa_custom_groups = self.company.get_sa_custom_group
    custom_groups = {}
    sa_custom_groups.each do |cg|
      custom_field_value = self.custom_field_values.where(custom_field_id: cg.id).take
      custom_groups[cg.id.to_s] = [custom_field_value.custom_field_option_id] if custom_field_value
    end
    collection_params["custom_groups"] = custom_groups
    collection_params["tab"] = "email"
    collection_params
  end

  def pm_integration_uid(api_name)
    integration = self.company.pm_integration_type(api_name)
    return unless integration != 'no_pm_integration'

    case integration
    when 'fifteen_five'
      return self.fifteen_five_id
    when 'peakon'
      return self.peakon_id
    when 'lattice'
      return self.lattice_id
    end
  end

  def manager_level level
    case level
    when '1'
      self.manager
    when '2'
      self.manager&.manager
    when '3'
      self.manager&.manager&.manager
    when '4'
      self.manager&.manager&.manager&.manager
    end
  end

  def manage_two_factor_authentication
    Users::ManageTfaJob.perform_later(self.company_id, self.id, false)
  end

  def get_invite_email_address
    if ["invited", "preboarding", "pre_start"].include?(self.current_stage) &&
      self.onboard_email == "personal"
      email = self.personal_email || self.email
    else
      email = self.email || self.personal_email
    end
  end

  def get_custom_coworker field_id
    if field_id == 'bdy'
      self.buddy
    else
      CustomFieldValue.find_by(custom_field_id: field_id, user_id: self.id)&.coworker
    end
  end

  def get_ctus_field_data custom_field, ctus, default_field
    value = nil

    if custom_field
      custom_snapshot = ctus.custom_snapshots.where(custom_field_id: custom_field.id).last
      if custom_snapshot.present?
        value = custom_snapshot.custom_field_value
        value = custom_field.coworker? ? get_coworker_field_value(value) : value
        value = (custom_field.mcq? || custom_field.employment_status?) ? custom_field.custom_field_options.find_by_id(value).try(:option) : value
        if custom_field.date?
          new_value = TimeConversionService.new(self.company).perform(value.to_date) rescue nil
          value = new_value.present? ? new_value : value
        end
      end

    elsif default_field
      value = get_default_field_value_text(ctus.custom_snapshots.where(preference_field_id: default_field['id']).last)
    end

    value
  end

  def is_admin_with_view_and_edit_people_page?
    self.user_role.role_type == 'admin' && self.user_role.permissions['platform_visibility']['people'] == 'view_and_edit' rescue false
  end

  def generate_packet_assignment_email_data document_token = ""
    return nil unless document_token.present?
    data = {}
    assigned_paperwork_requests = self.paperwork_requests.get_assigned_sibling_requests(document_token)
    assigned_upload_requests = self.user_document_connections.get_assigned_sibling_requests(document_token)

    data[:documents_count] = assigned_paperwork_requests.count + assigned_upload_requests.count rescue 0
    data[:user_document_link] = 'https://' + self.company.app_domain + '/#/documents/' + self.id.to_s
    data[:user_profile_picture] = self.picture rescue ''
    data[:user_initials] = self.initials rescue ''
    data[:user_name] = self.full_name rescue ''
    data[:document_list] = []

    assigned_paperwork_requests.try(:each) do |paperwork_request|
      break if data[:document_list].count == 3
      document_details = {}
      document_details["name"] = paperwork_request.document.title rescue ''
      document_details["type"] = "Signatory"
      document_details["due_date"] = paperwork_request.due_date.strftime('%B %d') rescue ''
      data[:document_list].push document_details
    end

    assigned_upload_requests.try(:each) do |upload_request|
      break if data[:document_list].count == 3
      document_details = {}
      document_details["name"] = upload_request.document_connection_relation.title rescue ''
      document_details["type"] = "Upload"
      document_details["due_date"] = upload_request.due_date.strftime('%B %d') rescue ''
      data[:document_list].push document_details
    end

    data
  end

  def get_custom_section_approval(custom_section_id)
    self.custom_section_approvals.find_by(custom_section_id: custom_section_id, state: CustomSectionApproval.states[:requested])
  end

  def change_bulk_requested_attributes()
    custom_section_approvals = self.custom_section_approvals.where(state: CustomSectionApproval.states[:requested])
    custom_section_approvals.try(:each) do |custom_section_approval|
      assign_requested_attributes(custom_section_approval.requested_fields)
    end
  end

  def change_requested_attributes(custom_section_id)
    cs_approval = get_custom_section_approval(custom_section_id)
    requested_fields = cs_approval.requested_fields if cs_approval.present?
    assign_requested_attributes(requested_fields)
  end

  def assign_requested_attributes(requested_fields)
    return unless requested_fields.present?
    requested_fields.try(:each) do |field|
      if ['first_name', 'last_name', 'preferred_name', 'personal_email', 'start_date'].include?(field.preference_field_id)
        self[field.preference_field_id.to_sym] = field[:custom_field_value]
      elsif field.preference_field_id == 'company_email'
        self[:email] = field[:custom_field_value]
      elsif field.preference_field_id == 'buddy'
        self[:buddy_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'department'
        self[:team_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'manager'
        self[:manager_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'location'
        self[:location_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'working_pattern'
        self[:working_pattern_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'job_title'
        self[:title] = field[:custom_field_value]
      elsif field.preference_field_id == 'status'
        self[:state] = field[:custom_field_value]
      elsif field.preference_field_id == 'access_permission'
        self[:user_role_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'about'
        self.profile[:about_you] = field[:custom_field_value]
      elsif field.preference_field_id == 'paylocityid'
        self[:paylocity_id] = field[:custom_field_value]
      elsif field.preference_field_id == 'trinetid'
        self[:trinet_id] = field[:custom_field_value]
      elsif ['facebook', 'twitter', 'github', 'linkedin'].include?(field.preference_field_id)
        self.profile[field.preference_field_id.to_sym] = field[:custom_field_value]
      end
    end
  end

  def get_default_fields_values_against_requested_attributes(requested_fields)
    return unless requested_fields.present?
    old_default_values = []
    new_default_values = []
    field_names = {}
    self.company.prefrences['default_fields'].map { |def_field| field_names.merge!("#{def_field['api_field_id']}": def_field['name']) if def_field['profile_setup'] == 'profile_fields' && ['user_id', 'profile_photo'].exclude?(def_field['api_field_id']) }.reject(&:nil?)
    requested_fields.try(:each) do |field|
      next unless field.preference_field_id.present?
      new_value = ''
      if field.preference_field_id == 'access_permission'
        new_value = self.company.user_roles.find_by_id(field[:custom_field_value])&.name
      elsif field.preference_field_id == 'buddy' || field.preference_field_id == 'manager'
        new_value = self.company.users.with_deleted.find_by(id: field[:custom_field_value])&.display_name
      elsif field.preference_field_id == 'department'
        new_value = self.company.teams.find_by(id: field[:custom_field_value])&.name
      elsif field.preference_field_id == 'location'
        new_value = self.company.locations.find_by(id: field[:custom_field_value])&.name
      else
        new_value = field[:custom_field_value]
      end
      old_default_values << { field_name: field_names[field.preference_field_id.to_sym].to_s.capitalize, field_value: get_prefrence_field(field.preference_field_id).to_s }
      if DATE_TYPE_DEFAULT_FIELDS.include?(field.preference_field_id)
        new_value = TimeConversionService.new(self.company).perform(new_value.to_date) rescue nil
      end
      new_default_values << { field_name: field_names[field.preference_field_id.to_sym].to_s.capitalize, field_value: new_value }
    end
    { new_values: new_default_values, old_values: old_default_values }
  end

  def get_custom_fields_values_against_requested_attributes(requested_fields)
    return unless requested_fields.present?
    old_default_values = []
    new_default_values = []
    field_names = {}
    self.company.custom_fields.where.not(custom_section_id: nil, section: nil).map { |cust_field| field_names.merge!("#{cust_field['id'].to_i}": cust_field['name']) }.reject(&:nil?)
    field_names = field_names.with_indifferent_access

    requested_fields.try(:each) do |field|
      next unless field.custom_field_id.present?

      old_default_values << { field_name: field_names["#{field[:custom_field_id].to_i}"].to_s.capitalize, field_value: get_custom_field_value_text(field_names["#{field[:custom_field_id].to_i}"]).to_s }
      new_default_values << { field_name: field_names["#{field[:custom_field_id].to_i}"].to_s.capitalize, field_value: get_custom_field_value_text_against_requested_field(self, field, field_names["#{field[:custom_field_id].to_i}"]) }
    end

    { new_values: new_default_values, old_values: old_default_values }
  end

  def get_custom_field_value_text_against_requested_field(user, requested_field, field_name)
    custom_field = user.company.custom_fields.find_by(id: requested_field.custom_field_id)
    return '' if custom_field.nil?

    if requested_field.field_type == 'mcq' || requested_field.field_type == 'employment_status'
      custom_field.custom_field_options.find_by(id: requested_field.custom_field_value["custom_field_option_id"])&.option

    elsif ['social_security_number', 'social_insurance_number', 'short_text', 'long_text', 'date', 'confirmation', 'number', 'simple_phone'].include?(requested_field.field_type)
      requested_field.custom_field_value['value_text']

    elsif requested_field.field_type == 'coworker'
      User.find_by(id: requested_field.custom_field_value['coworker_id'])&.display_name

    elsif requested_field.field_type == 'multi_select'
      custom_field.custom_field_options.find(requested_field.custom_field_value["checkbox_values"]).pluck(:option) rescue nil

    elsif ['address', 'currency', 'tax', 'phone', 'national_identifier'].include?(requested_field.field_type)
      get_sub_custom_fields_formatted(requested_field)
    end
  end

  def get_sub_custom_fields_formatted(requested_field)
    is_parametrize = requested_field.field_type == 'address' ? false : true
    new_value_hash = {}
    requested_field.custom_field_value["sub_custom_fields"].map do |value|
      key = is_parametrize ? value['name']&.downcase&.gsub(" ", "_") : value['name']&.downcase&.gsub(" ", "")
      new_value_hash.merge!("#{key}": (value['custom_field_value'].present? && value['custom_field_value'].key?('value_text') ? value['custom_field_value']['value_text'] : nil))
    end

    if requested_field.field_type == 'address'
      address = ""
      address += new_value_hash[:line1] if new_value_hash[:line1].present?
      address += ', ' + new_value_hash[:line2] if new_value_hash[:line2].present?
      address += ', ' + new_value_hash[:city] if new_value_hash[:city].present?
      address += ' ' + new_value_hash[:country] if new_value_hash[:country].present?
      address += '-' + new_value_hash[:state] if new_value_hash[:state].present?
      address += ', ' + new_value_hash[:zip] if new_value_hash[:zip].present?
      return address

    elsif requested_field.field_type == 'currency'
      currency_type = new_value_hash[:currency_type]
      currency_value = new_value_hash[:currency_value]

      currency_field_value = ""
      if currency_type.present? && currency_value.present?
        currency_field_value = currency_type + ',' + currency_value
      elsif currency_type.blank? && currency_value.present?
        currency_field_value = currency_value
      elsif currency_type.present? && currency_value.blank?
        currency_field_value = currency_type
      else
        currency_field_value = ''
      end
      return currency_field_value

    elsif requested_field.field_type == 'tax'
      tax_type = new_value_hash[:tax_type]
      tax_value = new_value_hash[:tax_value]

      tax_field_value = ''
      if tax_type.present? && tax_value.present?
        tax_field_value = tax_type + ',' + tax_value
      else
        tax_field_value = tax_type.present? ? tax_type : (tax_value.present? ? tax_value : '')
      end
      return tax_field_value

    elsif requested_field.field_type == 'phone'

      country = new_value_hash[:country]
      area = new_value_hash[:area]
      phone = new_value_hash[:phone]

      phone_number = ''
      country_code = ''
      if country
        country_code = ISO3166::Country.find_country_by_alpha3(country)&.country_code
      end
      phone_number += "'" + '+' + country_code unless country_code.blank?
      phone_number += ' ' + area if area
      phone_number += ' ' + phone if phone

      return phone_number

    elsif requested_field.field_type == 'national_identifier'
      return %i[id_country id_type id_number].map{|val| new_value_hash[val] }.join(',')
    end
  end

  def manager_level_count
    for index in 1 .. 4 do
      return index - 1 if !self.manager_level(index.to_s)
    end
    index
  end

  def user_sandbox_trial_available
    start_date && start_date >= ('2021-07-01').to_date && start_date >= (Date.today - 14.days)
  end

  def update_user_existing_manager_docs_cosigner
    manager_documents = self.reload.paperwork_requests.joins(document: :paperwork_template).where(co_signer_id: nil, paperwork_templates: { is_manager_representative: true }) rescue nil
    manager_documents.update_all(co_signer_id: self.manager_id) if !manager_documents.blank?
  end

  def pending_approved_pto_requests
    approved_requests = self.pto_requests.approved_requests.individual_requests.order_by_begin_date
    current = approved_requests.where('begin_date <= ?', Date.today).last
    if valid_partner_pto?(current)
      future = approved_requests.where('begin_date > ?', Date.today).ids
      ids = [current.id] + future
      all_requests = approved_requests.where(id: ids).includes(:partner_pto_requests).order_by_begin_date
      all_requests.map { |r| [r, r.partner_pto_requests.order_by_begin_date.last] }
    end
  end

  def get_default_field(field_name)
    self.company.prefrences['default_fields'].select { |default_field| default_field['name'].eql?(field_name) }
  end

  def remove_buddy_tasks
    self.task_user_connections&.draft_connections&.buddy_tasks&.destroy_all
  end

  def reset_pto_balances
    TimeOff::ResetPTOBalances.perform_async(self.id) if self.is_rehired?
  end

  def update_pending_hire(params)
    pending_hire = self.company.pending_hires.find_by(id: params[:pending_hire_id])
    return unless pending_hire

    pending_hire.update(pending_hire_params(params[:employee_type]))
  end

  def incomplete_documents_count
    count = User.user_incomplete_paperwork_requests_count(id) +
      User.user_incomplete_co_signer_paperwork_requests_count(id) +
      User.user_incomplete_upload_requests_count(id)
    count < 0 ? 0 : count
  end

  def remove_access
    return if self.remove_access_state == "removed"
    self.inactive_user
    self.should_execute_offboarding_webhook = self.saved_change_to_state? && self.inactive?
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'offboarding', type: 'offboarding', stage: 'completed', triggered_for: self.id, triggered_by: User.current.try(:id), user_id: self.id }) if self.saved_change_to_state? && self.inactive?
    self.update_attribute(:remove_access_state, "removed")
    self.offboarding!

    create_general_logging(self.company, 'states of user attributes while remove access', { result: "The current user is  #{self.state} with should_execute_offboarding_webhook #{self.should_execute_offboarding_webhook} and have current_stage of #{self.current_stage} and with remove_access_state #{self.remove_access_state}" })
    assign_last_balance_to_policies
    deactivate_profiles()
    terminate_user_from_xero if self.xero_id.present? && self.company.is_xero_integrated?
    terminate_user_from_adp()

    inactive_owner_tasks
    Location.expire_people_count(self.location_id)
    self.calendar_feeds.destroy_all
    remove_all_events_of_offboarded_user(self)
    self.suspend_gsuite_account
  end

  def execute_offboarding_webhook
    create_general_logging(self.company, "offboarding webhook executed for user #{self.id}", { result: '' })
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'offboarding', type: 'offboarding', stage: 'completed', triggered_for: self.id, triggered_by: User.current.try(:id), user_id: self.id })
    self.should_execute_offboarding_webhook = false
  end

  def get_termination_time
    return unless self.termination_date.present?

    if self.remove_access_timing == "default" || self.remove_access_timing == "remove_immediately"
      (self.termination_date + 1.day).to_time.change({hour: 1, offset: "UTC" })
    elsif self.remove_access_timing == "custom_date"
      self.remove_access_date.to_time.change({ hour: self.remove_access_time }).asctime.in_time_zone(self.remove_access_timezone)
    end
  end

  def save_profile_image(base64_img)
    return if base64_img.blank?

    Tempfile.open(%W[profile_img_#{id} .png]) do |temp_file|
      temp_file.binmode; temp_file.write(Base64.decode64(base64_img))
      new_file = UploadedFile::ProfileImage.where(get_profile_image_params).first_or_initialize
      new_file.file = temp_file
      new_file.save!
    end
  end

  def access_field_permission_service(current_user, employee, company, field_name)
    permission_service.canAccessField(current_user, employee, company, field_name)
  end

  def permission_service
    @permission_service ||= PermissionService.new
  end
  
  protected

  def nil_if_blank
    NULL_ATTRS.each { |attr| self[attr] = nil if self[attr].blank? }
  end

  def reset_current_user_for_test_env
    if Rails.env.test? && User.current.present? && User.current.company_id != self.company_id
      User.clear_current_user
    end
  end

  def show_performance_tabs
    performance_tabs = []
    performance_tabs.push({ name: 'fifteen_five', tab: '15Five' }) if pm_integration_uid('fifteen_five').present?
    performance_tabs.push({ name: 'peakon', tab: 'Peakon' }) if pm_integration_uid('peakon').present?
    performance_tabs.push({ name: 'lattice', tab: 'Lattice' }) if pm_integration_uid('lattice').present?

    return performance_tabs
  end

  def set_super_user_status
    self.update_column(:super_user, true)
  end

  def self.manager_reassign_tasks(user_id, previous_manager_id, task_type)
    TaskUserConnection.joins(:task).where(tasks: { task_type: task_type }, user_id: user_id, state: 'in_progress', owner_id: previous_manager_id) if user_id.present? && previous_manager_id.present? && task_type.present?
  end
  
  private

  def update_approval_chain_requests
    approval_tables = company.custom_tables.where(is_approval_required: true)
    approval_tables.each do |table|
      requested_snapshots = table.custom_table_user_snapshots.where(request_state: CustomTableUserSnapshot.request_states[:requested])
      requested_snapshots.each do |snapshot|
        approval = CtusApprovalChain.current_approval_chain(snapshot.id)[0]
        if approval&.requested?
          approvers = snapshot.approvers
          snapshot.manage_approval_snapshot_on_user_termination if approvers && (approvers['approver_ids'] - [self.id]).blank?
        end
      end
    end
  end

  def flush_manager_chain_cache(manager_id)
    manager = User.find_by(id: manager_id) if manager_id.present?
    seen_users = []
    until manager.nil?
      Rails.cache.delete([manager.id, 'indirect_reports_ids']) if manager.try(:id).present?
      seen_users.push(manager.id)
      break if manager.manager.present? && seen_users.include?(manager.manager.id)
      manager = manager.manager
    end
  end

  def cancel_inactive_pto_requests
    self.pto_requests.pending_and_future_requests(self.company.time.to_date).each do |request|
      next if request.assigned_pto_policy.blank?
      
      request.avoid_cancellation_email = true
      request.update_attribute(:status, 3)
      agent = User.current || self.company.users.where(super_user: true).take
      request.activities.create(agent_id: agent.id, description: I18n.t('onboard.home.time_off.activities.cancelled_request_on_offboarding'), activity_type: 'PtoRequest') if request
    end
  end

  def user_inactive_or_departed?
    (self.saved_changes[:current_stage].present? && self.current_stage == 'departed') || (self.saved_changes[:state].present? && self.state == 'inactive')
  end

  def if_evn_test?
    Rails.env.test?
  end

  def really_destroy_soft_deleted_relations
    self.task_owner_connections.with_deleted.each { |task_owner_connection| task_owner_connection.really_destroy! }
    self.task_user_connections.with_deleted.each { |tuc| tuc.really_destroy! }
    self.tasks.with_deleted.each { |task| task.really_destroy! }
    User.unscope(:where).where("users.deleted_at IS NOT NULL AND visibility = ? and manager_id = ?", false, self.id).each { |user| user.update_column(:manager_id, nil) }
    User.unscope(:where).where("users.deleted_at IS NOT NULL AND visibility = ? and buddy_id = ?", false, self.id).each { |user| user.update_column(:buddy_id, nil) }
    User.unscope(:where).where("users.deleted_at IS NOT NULL AND visibility = ? and account_creator_id = ?", false, self.id).each { |user| user.update_column(:account_creator_id, nil) }
  end

  def asigned_policies(policies_ids)
    user_pto_policies = []
    policies_ids.each do |policy|
      policy_to_restore = self.assigned_pto_policies.with_deleted.where(pto_policy_id: policy, manually_assigned: false).max_by { |obj| obj.id }
      if policy_to_restore.present?
        policy_to_restore.restore(recursive: true)
      else
        user_pto_policies << { pto_policy_id: policy, user_id: self.id }
      end
    end
    AssignedPtoPolicy.create(user_pto_policies) if policies_ids.present? && user_pto_policies.count > 0
  end

  def update_hellosign_signature_email
    begin
      UpdateSignatureRequestJob.perform_later(self.id, self.email_in_database, self.email) if self.changes_to_save["email"].present? && self.email_in_database.present?
      UpdateSignatureRequestJob.perform_later(self.id, self.personal_email_in_database, self.personal_email) if self.will_save_change_to_personal_email? && self.personal_email_in_database.present?
    rescue Exception => e
      puts e
    end
  end

  def assign_default_policy
    filters = set_fetching_policies_filters(self.team_id, self.location_id, self.get_employment_status)
    self.company.pto_policies.assigned_default_pto_policies_or_by_filters(filters[:filter_by_team], filters[:filter_by_location], filters[:filter_by_employment_status]).uniq.each do |policy|
      self.pto_policies << policy
    end
  end

  def set_fetching_policies_filters(team_id, location_id, employment_status)
    filter_by_employment_status = employment_status.present? ? [employment_status] : ['all']
    filter_by_team = team_id.present? ? [team_id] : ['all']
    filter_by_location = location_id.present? ? [location_id] : ['all']
    { filter_by_employment_status: filter_by_employment_status, filter_by_team: filter_by_team, filter_by_location: filter_by_location }
  end

  def set_calendar_events_settings
    # Set all gear checkbox to selected
    self.update_columns(calendar_preferences: { event_types: [0, 1, 2, 3, 4, 6] })
  end

  def calendar_event_related_fields_changed
    changed_event_hash = {}
    common_changed_attributes = self.saved_changes.keys & USER_EVENTS
    changed_event_hash['event_changed'] = common_changed_attributes.size > 0
    changed_event_hash['changed_attribute'] = common_changed_attributes
    changed_event_hash
  end

  def offboarding_initiated?
    state_changed = false
    offboarding_stages = ['last_week', 'last_month', 'departed']
    if self.saved_changes.key?("current_stage")
      previous_value = self.saved_changes['current_stage'].first
      new_value = self.saved_changes['current_stage'].last
      state_changed = (!(offboarding_stages.include? previous_value) and (offboarding_stages.include? new_value))
    end
    state_changed
  end

  def calendar_prefrences
    { enabled_calendar: self.company.enabled_calendar, prefrences: self.company.calendar_permissions }
  end

  def password_complexity
    if password.present? and not password.match(/(?=.*[0-9])(?=.*[\W_])/) || (password.present? and password.size < 8)
      errors.add(:Password, I18n.t('errors.invalid_complexity').to_s)
    end
  end

  def can_create_history_entry?
    auditing_fields_updated? && !self.updated_by_admin
  end

  def get_attribute_input_type attribute_name
    type = nil
    if User.defined_enums.present? and User.defined_enums.keys.include? attribute_name
      type = 'mcq'
    elsif User.reflect_on_all_associations.map(&:foreign_key).map(&:to_s).uniq.include? attribute_name
      if User.reflect_on_all_associations.map { |r| r.class_name == "User" ? r.foreign_key.to_s : nil }.uniq.compact.include? attribute_name
        type = 'autocomplete'
      else
        type = 'mcq'
      end
    elsif User.type_for_attribute(attribute_name).type.to_s == 'date'
      type = 'date'
    elsif User.type_for_attribute(attribute_name).type.to_s == 'integer'
      type = 'string'
    elsif User.type_for_attribute(attribute_name).type.to_s == 'string'
      type = 'string'
    elsif User.type_for_attribute(attribute_name).type.to_s == 'text'
      type = 'text'
    else
      type = 'text'
    end
    type
  end

  # If start date changed then need to update calender events accordingly
  def update_anniversary_events
    if self.active? && !self.user_is_ghost
      self.create_default_anniversaries
    end
  end

  def update_tasks_date
    if self.update_task_dates.nil? || self.update_task_dates
      old_start_date = start_date_before_last_save.to_s if saved_change_to_start_date?

      UpdateTaskDueDateJob.perform_later(self.id, true, false, old_start_date, true)
    end
  end

  def update_first_day_snapshots
    return if self.departed? # avoids overwriting old snapshots during rehiring flow
    if self.custom_table_user_snapshots.count > 0
      snapshots = self.custom_table_user_snapshots.joins(:custom_table).where(custom_table_user_snapshots: { effective_date: self.start_date_before_last_save, is_applicable: true }, custom_tables: { table_type: 0 })
      snapshots.each do |snapshot|
        snapshot.update_column(:effective_date, self.start_date)
        snapshot.custom_snapshots.find_by(custom_field_id: snapshot.custom_table.custom_fields.find_by(name: "Effective Date").id).update_column(:custom_field_value, self.start_date)
      end
    end
  end

  def update_assigned_policies_dates
    TimeOff::UpdatePolicyDates.perform_async({ id: self.id })
  end

  def get_default_field_value_text custom_snapshot
    if custom_snapshot && custom_snapshot.custom_field_value.present?
      case custom_snapshot.preference_field_id
      when 'dpt'
        dept = self.company.teams.find_by(id: custom_snapshot.custom_field_value)
        return dept.name if dept
      when 'loc'
        loc = self.company.locations.find_by(id: custom_snapshot.custom_field_value)
        return loc.name if loc
      when 'jt'
        return custom_snapshot.custom_field_value
      when 'man'
        manager = self.company.users.find_by(id: custom_snapshot.custom_field_value)
        return manager.display_name if manager
      when 'st'
        return custom_snapshot.custom_field_value.try(:downcase)
      end
    end
  end

  def get_currency_field_value value, field
    if value.present?
      new_val = value.split('|')
      if field.split(RPFLD_DELIMITER)[1] && field.split(RPFLD_DELIMITER)[1] == 'Currency'
        return new_val[0]
      else
        return sprintf("%0.02f", new_val[1].to_f)
      end
    end
  end

  def get_international_phone value
    data = ""
    if value
      phone = value.split('|')
      data = "'+#{ISO3166::Country.find_country_by_alpha3(phone[0])&.country_code} #{phone[1]} #{phone[2]}"
    end
    data
  end

  def get_coworker_field_value value
    coworker = self.company.users.find_by(id: value)
    return coworker.display_name if coworker
  end

  def get_custom_field_value field, ctus, custom_field, default_field, terminated_data
    value = nil
    if custom_field
      custom_snapshot = ctus.custom_snapshots.where(custom_field_id: custom_field.id).last
      if custom_snapshot.present?
        value = custom_snapshot.custom_field_value
        value = custom_field.coworker? ? get_coworker_field_value(value) : value
        value = (custom_field.mcq? || custom_field.employment_status?) ? custom_field.custom_field_options.find_by_id(value).try(:option) : value
        value = get_currency_field_value(value, field) if custom_field.currency?
        value = get_international_phone(value) if custom_field.phone?
        if custom_field.date?
          new_value = TimeConversionService.new(self.company).perform(value.to_date) rescue nil
          value = new_value.present? ? new_value : value
        end
      end
    elsif terminated_data
      value = ctus.terminated_data[field.parameterize.underscore]
      if field.parameterize.underscore == 'last_day_worked'
        new_value = TimeConversionService.new(self.company).perform(value.to_date) rescue nil
        value = new_value.present? ? new_value : value
      end
    elsif default_field
      return nil if ctus.present? && ((ctus.terminated_data.present? && ['Last Day Worked', 'Termination Type', 'Eligible For Rehire'].include?(field)) || (ctus.terminated_data.blank? && ['Termination Date', 'Last Day Worked', 'Termination Type', 'Eligible For Rehire'].include?(field)))
      value = get_default_field_value_text(ctus.custom_snapshots.where(preference_field_id: default_field['id']).last)
      value = get_prefrence_field(field.parameterize.underscore) if value.blank?
    end
    return value
  end

  def get_custom_table_field field, ctus, report, custom_table_id
    value = nil
    custom_table = self.company.custom_tables.find_by_id custom_table_id
    return value unless custom_table

    enabled_history = report.custom_tables.select { |p| p['name'] == custom_table.name }.first['enabled_history'] rescue nil
    if enabled_history
      if custom_table.table_type == 'standard'
        ctus = ctus.class.name == "CustomTableUserSnapshot" ? ctus : self.custom_table_user_snapshots.where("state = 1 AND custom_table_id = ?", custom_table.id).order(updated_at: :desc).first
      else
        ctus = ctus.class.name == "CustomTableUserSnapshot" ? ctus : self.custom_table_user_snapshots.where("state = 1 AND custom_table_id = ?", custom_table.id).order(effective_date: :desc).first
      end
    else
      if custom_table.table_type == 'standard'
        ctus = self.custom_table_user_snapshots.where("state = 1 AND custom_table_id = ?", custom_table.id).order(updated_at: :desc).first
      else
        ctus = self.custom_table_user_snapshots.where("state = 1 AND custom_table_id = ?", custom_table.id).order(effective_date: :desc).first
      end
    end

    if ctus.present?
      name = field == "Effective Date (#{custom_table.name})" ? "Effective Date" : field
      if name.split(RPFLD_DELIMITER).length > 1
        name = name.split(RPFLD_DELIMITER)[0]
      end
      custom_field = custom_table.custom_fields.find_by(name: name)
      terminated_data = ctus.terminated_data[field.parameterize.underscore] rescue nil
      default_field = report.company.prefrences['default_fields'].select { |p| p['name'].titleize == field }.first if terminated_data.blank?
      value = get_custom_field_value(field, ctus, custom_field, default_field, terminated_data)
    end
    return value
  end

  def get_point_in_time_table_data field, report, custom_table_id
    value = nil
    if CustomTable.custom_table_properties.keys.include?(custom_table_id)
      custom_table = self.company.custom_tables.find_by(custom_table_property: CustomTable.custom_table_properties[custom_table_id])
    else
      custom_table = self.company.custom_tables.find_by_id custom_table_id
    end
    return value unless custom_table
    date = Date.strptime(report.meta['end_date'], '%m/%d/%Y') rescue Date.today
    if custom_table.table_type == 'standard'
      ctus = self.custom_table_user_snapshots.where("updated_at <= ? AND custom_table_id = ?", date.end_of_day, custom_table.id).order(updated_at: :desc).first
    elsif !report.meta['pending_changes'] && custom_table.is_approval_required
      ctus = self.custom_table_user_snapshots.where(request_state: CustomTableUserSnapshot.request_states[:approved]).where("effective_date <= ? AND custom_table_id = ?", date, custom_table.id).order(effective_date: :desc).first
    else
      ctus = self.custom_table_user_snapshots.where("effective_date <= ? AND custom_table_id = ?", date, custom_table.id)
      applicable_ctus = ctus.where(is_applicable: true)
      ctus = (applicable_ctus.any? ? applicable_ctus : ctus).order(effective_date: :desc, updated_at: :desc).first
    end
    if ctus.present?
      name = field == "Effective Date (#{custom_table.name})" ? "Effective Date" : field
      if name.split(RPFLD_DELIMITER).length > 1
        name = name.split(RPFLD_DELIMITER)[0]
      end
      custom_field = custom_table.custom_fields.find_by(name: name)
      terminated_data = ctus.terminated_data[field.parameterize.underscore] rescue nil
      default_field = report.company.prefrences['default_fields'].select { |p| p['name'].titleize == field || p['name'] == field.try(:titleize) }.first if terminated_data.blank?
      value = get_custom_field_value(field, ctus, custom_field, default_field, terminated_data)
    end
    return value
  end

  def get_prefrence_field field
    case field
    when 'first_name'
      self.first_name
    when 'last_name'
      self.last_name
    when 'preferred_name'
      self.preferred_name
    when 'company_email'
      self.email
    when 'personal_email'
      self.personal_email
    when 'department'
      self.get_team_name
    when 'start_date'
      self.start_date.present? ? TimeConversionService.new(self.company).perform(self.start_date.to_date) : ''
    when 'location'
      self.get_location_name
    when 'working_pattern'
      self.working_pattern_id
    when 'last_day_worked'
      self.last_day_worked.present? ? TimeConversionService.new(self.company).perform(self.last_day_worked.to_date) : ''
    when 'job_title'
      self.title
    when 'employement_status'
      self.employee_type.present? ? self.employee_type.titleize : ''
    when 'termination_date'
      self.termination_date.present? ? TimeConversionService.new(self.company).perform(self.termination_date.to_date) : ''
    when 'termination_type'
      self.termination_type
    when 'eligible_for_rehire'
      self.eligible_for_rehire
    when 'manager'
      self.manager.present? ? self.manager.display_name : ''
    when 'access_permission'
      self.user_role&.role_type
    when 'about_you', 'about'
      get_cached_about_you
    when 'linkedin'
      self.profile.try(:linkedin)
    when 'twitter'
      self.profile.try(:twitter)
    when 'github'
      self.profile.try(:github)
    when 'buddy'
      self.buddy.present? ? self.buddy.display_name : ''
    when 'job_tier'
      self.job_tier.present? ? self.job_tier : ''
    when 'status'
      self.state
    when 'user_id'
      self.id
    when 'paylocity id', 'paylocity_id'
      self.paylocity_id
    when 'trinetid'
      self.trinet_id
    when 'manager_email'
      self.manager.nil? ? '' : self.manager.email
    when 'last_active'
      self.last_active.present? ? self.last_active.to_date.to_s : ''
    when 'last_sign_in_at'
      self.last_sign_in_at.present? ? self.last_sign_in_at.to_time.in_time_zone(self.company.time_zone).to_s : ''
    when 'stage'
      self.current_stage
    when 'length_of_service'
      service = ""
      if self.last_day_worked.present?
        service_length = (((self.last_day_worked - self.start_date).to_f) / 30).round
        years = service_length / 12
        months = service_length % 12
        if years && years > 0
          if years == 1
            service = service + "#{years} year"
          else
            service = service + "#{years} years"
          end
          if months && months > 0
            if months == 1
              service = service + ", #{months} month"
            else
              service = service + ", #{months} months"
            end
          end
        elsif months && months > 0
          if months == 1
            service = service + "#{months} month"
          else
            service = service + "#{months} months"
          end
        else
          service = "less than a month"
        end
      end
      service
    end
  end

  def update_last_modified_at
    self.update_columns(fields_last_modified_at: Time.now)
  end

  def get_profile_field_histories_data(custom_field, current_change, previous_change, report_permanent_fields)
    if previous_change.nil?
      previous_change = FieldHistory.where(field_name: current_change.field_name,
                                           custom_field_id: current_change.custom_field_id,
                                           field_auditable_type: current_change.field_auditable_type,
                                           field_auditable_id: current_change.field_auditable_id,
                                           created_at: DateTime.new .. current_change.created_at)
                                    .where.not(id: current_change.id)
                                    .order(created_at: :desc).first
    end

    if custom_field['isDefault'] != nil
      profile_setup = custom_field['profile_setup'] == 'custom_table' ? custom_field['custom_table_property'].titleize : custom_field['section'].titleize
    else
      profile_setup = custom_field.custom_table_id ? custom_field.custom_table.try(:name) : custom_field['section'].titleize
    end
    profile_setup_type = custom_field['field_type'].titleize

    previous_value = previous_change.try(:new_value)
    current_value = current_change.try(:new_value)
    return if profile_setup_type.eql?('Currency') && previous_value.blank? && current_value.blank?

    if profile_setup_type == "Date"
      previous_value = TimeConversionService.new(self.company).perform(previous_value.to_date) if previous_value.present?
      current_value = TimeConversionService.new(self.company).perform(current_value.to_date) if current_value.present?
    end

    if profile_setup_type == 'Address'
      begin
        previous_value &&= eval(previous_value).values.to_csv(row_sep: nil)
        current_value &&= eval(current_value).values.to_csv(row_sep: nil)
      rescue Exception => e
        previous_value &&= filterSubCustomFields(previous_value)
        current_value &&= filterSubCustomFields(current_value)
      end
    end
    if (profile_setup_type == 'Short Text' || profile_setup_type == 'Long Text')
      if current_value && current_value.scan(/\D/).empty?
        current_value = "'#{current_value}'"
      end
      if previous_value && previous_value.scan(/\D/).empty?
        previous_value = "'#{previous_value}'"
      end
    end
    field_data = []
    [TimeConversionService.new(self.company).perform(current_change.created_at.to_date),
     current_change.field_changer.try(:preferred_full_name), current_change.field_changer.try(:id), self.guid,
     track_user_default_field_values(report_permanent_fields), profile_setup, custom_field['api_field_id'],
     custom_field['name'], profile_setup_type, previous_value, current_value].flatten.each do |value|
      if value.present?
        if (value[0] == '0' && !value.include?("/")) || value[0] == '+'
          value = "'#{value}'"
        else
          value = "#{value}"
        end
      end
      field_data << value
    end
    return field_data
  end

  def filterSubCustomFields(value)
    value = value.gsub(" ,", "")
    value = value.strip
    if value.starts_with?(", ")
      value = value.sub ", ", ""
    end
    if value.ends_with?(",")
      value = value.chomp ","
    end
    return value
  end

  def return_gsheet_custom_field custom_field, custom_field_values, cf = nil
    value_text = " "
    if custom_field_values.present?
      if cf && cf.currency?
        if custom_field.split(RPFLD_DELIMITER).last == 'Currency'
          custom_field = 'Currency Type'
        else
          custom_field = 'Currency Value'
        end
      end

      if cf && cf.sub_custom_fields.present? && SubCustomField.show_sub_custom_fields(cf)
        tokenized_name = custom_field.split(RPFLD_DELIMITER)
        field_name = tokenized_name[tokenized_name.length - 1]
        sub_cf = cf.sub_custom_fields.find_by(name: field_name)
        sub_value = custom_field_values.find_by_sub_custom_field_id(sub_cf.try(:id))
        if sub_value.present?
          value_text = sub_value.value_text rescue nil
        end
      elsif cf && cf.field_type == 'multi_select'
        custom_field_value = custom_field_values.where(custom_field_id: cf.id, user_id: self.id).first
        value_text = cf.custom_field_options.where(id: custom_field_value.checkbox_values).pluck(:option).join(", ") if custom_field_value.present?
      else
        value_text = get_custom_field_value_text(custom_field, false, nil, nil, false, cf.id, false, false, false, false, nil, false, true)
        value_text = TimeConversionService.new(self.company).perform(value_text.to_date) if cf.date? && value_text
      end
    end
    value_text ? value_text : ""
  end

  def manager_form_completion
    if self.account_creator.present? && manager_field_exists?
      self.update_column :is_form_completed_by_manager, 1
    end
  end

  def update_free_admin_role
    manager = User.find_by(id: self.manager_id_before_last_save)
    if manager && manager.managed_users.length == 0 && manager.user_role && manager.user_role.role_type == 'manager'
      manager.set_employee_role
    end
  end

  def create_calendar_events
    setup_calendar_event(self, 'start_date', self.company)
    setup_calendar_event(self, 'anniversary', self.company)
  end

  def update_calendar_events
    Team.expire_people_count(self.team_id) if self.team_id.present? # On change state update cached data
    Location.expire_people_count(self.location_id) if self.location_id.present?
    if self.state == 'active'
      create_calendar_event_for_individual_user(self)
    else
      remove_all_events_of_offboarded_user(self, true)
      update_approval_chain_requests
    end
  end

  def nullify_accounnt_creator_id
    users = self.company.users.with_deleted
    if users.length > 0
      users.where(account_creator_id: self.id).update_all(account_creator_id: nil)
      users.where(manager_id: self.id).update_all(manager_id: nil)
      users.where(buddy_id: self.id).update_all(buddy_id: nil)
      users.where(created_by_id: self.id).update_all(created_by_id: nil)
    end
  end

  def set_guid
    update_column(:guid, generate_unique_guid)
  end

  def generate_unique_guid
    loop do
      temp_guid = "#{id}#{SecureRandom.uuid}"
      break temp_guid unless User.with_deleted.where(company_id: self.company_id, guid: temp_guid).exists?
    end
  end

  def self.pto_requests_pending_approval_count(user_id)
    total_count = 0
    User.where(manager_id: user_id).each do |user|
      total_count = total_count + user.pto_requests.individual_requests.pending_requests.count
    end
    total_count
  end

  def remove_spacing_in_name
    first_name.strip!
    last_name.strip!
    preferred_name&.strip!
  end

  def assign_last_balance_to_policies
    assigned_policies = self.assigned_pto_policies.joins(:pto_policy).where("pto_policies.allocate_accruals_at = ? and pto_policies.unlimited_policy = false and pto_policies.is_enabled = true", 1)
    assigned_policies.each do |ap|
      last_accrual = ap.balance_updated_at.present? ? ap.balance_updated_at : ap.start_of_accrual_period
      if (last_accrual < self.termination_date)
        Pto::ManagePtoBalances.new(1, self.company, true).add_balance_to_individual_assigned_policies([ap], true)
      end
    end
  end

  def update_org_chart_on_current_stage_changed?
    self.saved_change_to_current_stage? and ((ACTIVE_CURRENT_STAGES.include?(self.current_stage) and INACTIVE_CURRENT_STAGES.include?(self.current_stage_before_last_save)) || (ACTIVE_CURRENT_STAGES.include?(self.current_stage_before_last_save) and INACTIVE_CURRENT_STAGES.include?(self.current_stage)))
  end

  def auto_denny_related_pto_requests
    if self.managed_user_ids && self.managed_user_ids.count > 0
      self.managed_users.try(:each) do |managed_user|
        managed_user.pto_requests.where(status: 0).find_each { |m| m.update(status: 2) }
      end
    end
  end

  def terminate_user_from_xero
    TerminateEmployeeFromXeroJob.set(wait: 10.seconds).perform_later(self.id)
  end

  def terminate_user_from_adp
    update_adp_profile(self.id, 'Termination Date', nil, { termination_date: self.termination_date&.strftime("%Y-%m-%d"), last_day_worked: self.last_day_worked&.strftime("%Y-%m-%d") }.to_json) if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| self.company.integration_types.include?(api_name) }.present? && (self.adp_wfn_us_id.present? || self.adp_wfn_can_id.present?)
  end

  def manage_user_state_in_adfs
    ::SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.perform_async(self.id, ['state']) if self.active_directory_object_id.present?
  end

  def get_user_email(option)
    to_emails = []
    if option == "both"
      to_emails.push(self.email) if self.email.present?
      to_emails.push(self.personal_email) if self.personal_email.present?
    elsif option == "personal"
      self.personal_email.present? ? to_emails.push(self.personal_email) : to_emails.push(self.email)
    elsif option == "company"
      self.email.present? ? to_emails.push(self.email) : to_emails.push(self.personal_email)
    end
    to_emails
  end

  def create_webhook_events
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'stage_completed', type: 'stage_completed', stage: self.current_stage_before_last_save, triggered_for: id, triggered_by: User.current.try(:id) })
    WebhookEventServices::ManageWebhookEventService.new.initialize_event(company, { event_type: 'stage_started', type: 'stage_started', stage: self.current_stage, triggered_for: id, triggered_by: User.current.try(:id) })
  end

  def is_city_not_required(country)
    country.present? && ['singapore'].include?(country.downcase)
  end

  def valid_partner_pto?(current_pto)
    return false unless current_pto

    if current_pto.partner_pto_requests.present?
      current_pto.partner_pto_requests.order_by_begin_date.last&.end_date >= Date.today
    else
      current_pto.end_date >= Date.today
    end
  end

  def inactive_owner_tasks
    self.task_owner_connections.where.not(state: 'completed', user_id: id).destroy_all
  end

  def pending_hire_params(employee_type)
    {
      user_id: self.id,
      first_name: self.first_name,
      last_name: self.last_name,
      start_date: self.start_date,
      team_id: self.team_id,
      location_id: self.location_id,
      manager_id: self.manager_id,
      title: self.title,
      employee_type: employee_type,
      preferred_name: self.preferred_name
    }
  end

  def manager_field_exists?
    if onboarding_profile_template.present?
      collect_from_manager_field_exists?
    else
      company.custom_fields.where(collect_from: CustomField.collect_froms['manager']).any?
    end
  end

  def collect_from_manager_field_exists?
    profile_template_connections = onboarding_profile_template.profile_template_custom_field_connections
                                                              .includes(:custom_field)
    manager_custom_fields?(profile_template_connections) || manager_default_fields?(profile_template_connections)
  end

  def manager_custom_fields?(profile_template_connections)
    profile_template_connections.where.not(custom_field_id: nil)
                                .where(custom_fields: { collect_from: CustomField.collect_froms['manager'] }).any?
  end

  def manager_default_fields?(profile_template_connections)
    default_field_ids = profile_template_connections.where.not(default_field_id: nil).pluck(:default_field_id)
    return false unless default_field_ids.present?

    company.prefrences['default_fields'].detect do |field|
      default_field_ids.include?(field['id']) && field['collect_from'].include?('manager')
    end
  end

  def remove_manager_tasks
    task_user_connections.joins(:task).where(tasks: { task_type: 'manager' }, state: %w[draft in_progress])
                         .destroy_all
  end

  def deactivate_profiles(); deactivate_integration_profiles(['namely', 'fifteen_five', 'lattice', 'gusto']); end

  def current_time_zone
    Time.now.in_time_zone(self.remove_access_timezone)
  end

  def template_LDE_filters(collection_params, employee_type_option_id, location_id, team_id)
    employee_type_field_id = company.custom_fields.find_by(field_type: 13)&.id

    (should_add_filter?('loc') && location_id.present?) ? collection_params.merge!({ location_id: [location_id] }) : collection_params.delete(:location_id)
    (should_add_filter?('dpt') && team_id) ? collection_params.merge!({ team_id: [team_id] }) : collection_params.delete(:team_id)
    (should_add_filter?(employee_type_field_id.to_s) && employee_type_option_id) ? collection_params.merge!(employment_status_id: [employee_type_option_id]) : collection_params.delete(:employment_status_id)
  end

  def should_add_filter?(filter)
    sa_configuration = company.smart_assignment_configuration&.meta&.dig('smart_assignment_filters')
    (company.smart_assignment_2_feature_flag && sa_configuration&.include?(filter)) || !company.smart_assignment_2_feature_flag
  end

  def reactivate_profiles(user)
    update_adp_profile(user.id, 'is rehired', nil) if ['adp_wfn_us', 'adp_wfn_can'].select {|api_name| user.company.integration_types.include?(api_name) }.present? && (user.adp_wfn_us_id.present? || user.adp_wfn_can_id.present?)
  end

  def get_profile_image_params
    {
      company_id: company_id,
      original_filename: "profile_image_#{id}",
      entity_id: id,
      entity_type: 'User'
    }
  end
  
  def is_url_valid?(url)
    url_regexp = /\A(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?\z/ix
    url =~ url_regexp
  end
end

def track_user_default_field_values(permanent_fields)
  field_values = []
  default_fields = ActiveSupport::HashWithIndifferentAccess.new({
                                                                  ui: self.id,
                                                                  fn: self.first_name,
                                                                  ln: self.last_name,
                                                                  ce: self.email })
  default_fields_keys = default_fields.keys
  permanent_fields.try(:each) do |field|
    field_values << default_fields[field] if default_fields_keys.include?(field)
  end

  field_values
end
