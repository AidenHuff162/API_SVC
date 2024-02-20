module CompanySerializer
  class General < ActiveModel::Serializer
    attributes :id, :name, :abbreviation, :email, :bio, :time_zone, :brand_color, :company_video,
               :locations_count, :logo, :prefrences, :singular_department, :plauralize_department,
               :buddy, :company_value, :include_activities_in_email,:phone_format, :manager_form_emails, :welcome_note,
               :company_about, :preboarding_note, :preboarding_title, :subdomain, :date_format, :overdue_notification,
               :enabled_calendar, :timeout_interval, :sender_name, :notifications_enabled, :enabled_org_chart, :is_using_custom_table, :about_section, :milestone_section,
               :values_section, :team_section, :onboard_class_section, :welcome_section, :preboarding_section, :default_country, :default_currency,
               :login_type, :domain, :show_saml_login_button, :show_adfs_link, :calendar_permissions, :preboard_people_settings, :links_enabled,
               :send_notification_before_start, :team_digest_email, :display_name_format, :default_email_format,
               :otp_required_for_login, :flatfile_access_flag, :enabled_time_off, :sa_disable, :pending_hire_flatfile_access_flag, :intercom_feature_flag, :org_paywall_feature_flag,
               :company_plan, :zendesk_admin_feature_flag, :smart_assignment_2_feature_flag, :ui_switcher_feature_flag, :pto_requests_feature_flag

    has_one :operation_contact, serializer: UserSerializer::Owner
    has_one :organization_root, serializer: UserSerializer::Owner
    has_many :milestones
    has_many :company_values
    has_many :company_links
    has_one :display_logo_image
    has_one :landing_page_image
    has_many :gallery_images

    def plauralize_department
      object.department.pluralize
    end

  end
end
