class CompanyForm < BaseForm
  SINGULAR_RELATIONS = %i(display_logo_image landing_page_image)
  PLURAL_RELATIONS = %i(milestones company_values gallery_images custom_tables company_links)
  RESERVED_SUBDOMAINS = %w(www)

  attribute :subdomain, String
  attribute :name, String
  attribute :abbreviation, String
  attribute :brand_color, String
  attribute :bio, String
  attribute :time_zone, String
  attribute :hide_gallery, Boolean
  attribute :company_values, Array[CompanyValueForm]
  attribute :company_links, Array[CompanyLinkForm]
  attribute :milestones, Array[MilestoneForm]
  attribute :custom_tables, Array[CustomTableForm]
  attribute :display_logo_image, UploadedFileForm::DisplayLogoImageForm
  attribute :landing_page_image, UploadedFileForm::LandingPageImageForm
  attribute :company_video, String
  attribute :gallery_images, Array[UploadedFileForm::GalleryImageForm]
  attribute :prefrences, JSON
  attribute :new_tasks_emails, Boolean
  attribute :outstanding_tasks_emails, Boolean
  attribute :new_coworker_emails, Boolean
  attribute :preboarding_complete_emails, Boolean
  attribute :new_manager_form_emails, Boolean
  attribute :document_completion_emails, Boolean
  attribute :buddy_emails, Boolean
  attribute :manager_emails, Boolean
  attribute :start_date_change_emails, Boolean
  attribute :department, String
  attribute :buddy, String
  attribute :company_value, String
  attribute :overdue_notification, Integer
  attribute :date_format, String
  attribute :manager_form_emails, Boolean
  attribute :include_activities_in_email, Boolean
  attribute :welcome_note, String
  attribute :operation_contact_id, Integer
  attribute :include_documents_preboarding, Boolean
  attribute :new_pending_hire_emails, Boolean
  attribute :company_about, String
  attribute :sender_name, String
  attribute :organization_root_id, Integer
  attribute :preboarding_note, String
  attribute :preboarding_title, String
  attribute :onboarding_activity_notification, Boolean
  attribute :transition_activity_notification, Boolean
  attribute :offboarding_activity_notification, Boolean
  attribute :role_types, JSON
  attribute :timeout_interval, Integer
  attribute :notifications_enabled, Boolean
  attribute :about_section, JSON
  attribute :milestone_section, JSON
  attribute :values_section, JSON
  attribute :team_section, JSON
  attribute :onboard_class_section, JSON
  attribute :welcome_section, JSON
  attribute :default_country, String
  attribute :default_currency, String
  attribute :display_name_format, Integer
  attribute :default_email_format, Integer
  attribute :login_type, Integer
  attribute :calendar_permissions, JSON
  attribute :preboard_people_settings, JSON
  attribute :paylocity_integration_type, String
  attribute :paylocity_sui_state, String
  attribute :links_enabled, Boolean
  attribute :send_notification_before_start, Boolean
  attribute :team_digest_email, Boolean
  attribute :error_notification_emails, Array[String]
  attribute :otp_required_for_login, Boolean
  attribute :sa_disable, Boolean
  
  validates :name, :subdomain, presence: true
  validates :subdomain, uniqueness: { model: Company }
  validates :subdomain, subdomain: { reserved: RESERVED_SUBDOMAINS }
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
  validates_format_of :name, with: Regexp.new(AvoidHtml::HTML_REGEXP)
end
