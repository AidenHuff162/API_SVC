class UserForm < BaseForm
  presents :user

  SINGULAR_RELATIONS = %i(profile_image)

  attribute :first_name, String
  attribute :last_name, String
  attribute :email, String
  attribute :personal_email, String
  attribute :title, String
  attribute :start_date, Date
  attribute :location_id, Integer
  attribute :manager_id, Integer
  attribute :buddy_id, Integer
  attribute :team_id, Integer
  attribute :company_id, Integer
  attribute :created_by_id, Integer
  attribute :profile_image, UploadedFileForm::ProfileImageForm
  attribute :state, String
  attribute :onboard_email, Integer
  attribute :provider, String
  attribute :uid, String
  attribute :role, Integer
  attribute :roadmap_id, Integer
  attribute :termination_date, Date
  attribute :current_stage, Integer
  attribute :preferred_name, String
  attribute :invited_employee, Boolean
  attribute :preboarding_progress, JSON
  attribute :calendar_preferences, JSON
  attribute :onboarding_progress, Integer
  attribute :is_form_completed_by_manager, Integer
  attribute :account_creator_id, Integer
  attribute :job_tier, String
  attribute :last_day_worked, Date
  attribute :termination_type, Integer
  attribute :eligible_for_rehire, Integer
  attribute :old_start_date, Date
  attribute :fields_last_modified_at, DateTime
  attribute :paylocity_id, String
  attribute :provision_gsuite, Boolean
  attribute :seen_profile_setup, Boolean
  attribute :send_credentials_type, Integer
  attribute :seen_documents_v2, Boolean
  attribute :send_credentials_offset_before, Integer
  attribute :send_credentials_time, Integer
  attribute :send_credentials_timezone, String
  attribute :workday_id, String
  attribute :workday_id_type, String
  attribute :workday_worker_subtype, String
  attribute :onboarding_profile_template_id, String
  attribute :offboarding_profile_template_id, String
  attribute :last_used_profile_template_id, String
  attribute :adp_onboarding_template, String
  attribute :remove_access_timing, Integer
  attribute :remove_access_date, Date
  attribute :remove_access_time, Integer
  attribute :remove_access_timezone, String
  attribute :smart_assignment, Boolean
  attribute :trinet_id, String
  attribute :terminate_pto_callback, Boolean
  attribute :update_task_dates, Boolean
  attribute :namely_id, String
  attribute :created_by_source, String
  attribute :working_pattern_id, Integer

  validate :company_or_personal_email?
  validates :company_id, :first_name, :last_name, :start_date, presence: true
  validates :email, :personal_email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "Only allows valid emails" }, allow_blank: true
  validates_format_of :first_name, :last_name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
  validates_format_of :preferred_name, with: Regexp.new(AvoidHtml::HTML_REGEXP), allow_nil: true

  before_validation :update_onboard_email
  before_validation :set_provider_and_uid
  before_validation :set_empty_as_nil

  private
  def update_onboard_email
    if !self.email && (!self.onboard_email || self.onboard_email == 'both' || self.onboard_email == 'company')
      self.onboard_email = 0

    elsif !self.personal_email && (!self.onboard_email || self.onboard_email == 'both' || self.onboard_email == 'personal')
      self.onboard_email = 1

    elsif self.personal_email && self.email && !self.onboard_email
      self.onboard_email = 2
    end
  end

  def company_or_personal_email?
    email.present? || personal_email.present?
  end

  def set_empty_as_nil
    self.personal_email = nil if personal_email == ''
    self.email = nil if email == ''
  end

  def set_provider_and_uid
    self.uid = self.user.id || (self.personal_email || self.email)
    if onboard_email && ((onboard_email == 0 || onboard_email == 'personal') && personal_email)
      self.provider = 'personal_email'
    elsif onboard_email && ((onboard_email == 1 || onboard_email == 'company') && email)
      self.provider = 'email'
    end
  end
end
