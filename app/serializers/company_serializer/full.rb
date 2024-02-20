module CompanySerializer
  class Full < ActiveModel::Serializer
    attributes :id, :name, :email_address, :abbreviation, :email, :bio, :time_zone,
               :brand_color, :company_video, :outstanding_tasks_emails,
               :users_count, :teams_count, :locations_count, :logo, :prefrences, :is_recruitment_system_integrated,
               :new_tasks_emails, :new_coworker_emails,
               :google_auth_enable, :people_count, :singular_department, :plauralize_department,
               :buddy, :company_value, :include_activities_in_email,
               :preboarding_complete_emails, :buddy_emails, :manager_emails,
               :overdue_notification, :phone_format, :manager_form_emails, :is_namely_integrated,
               :is_jira_enabled, :welcome_note, :integration_type, :ats_integration_types,
               :include_documents_preboarding, :authentication_type,
               :new_pending_hire_emails, :enable_gsuite_integration,
               :gsuite_account_exists, :company_about, :flatfile_access_flag,
               :new_manager_form_emails, :document_completion_emails,
               :preboarding_note, :preboarding_title, :subdomain,
               :onboarding_activity_notification, :transition_activity_notification,
               :offboarding_activity_notification,
               :enabled_org_chart, :enabled_calendar, :date_format,
               :role_types, :enabled_time_off, :is_using_custom_table, :start_date_change_emails, :show_adfs_link,
               :adfs_sso_link, :show_saml_login_button, :timeout_interval, :custom_tables_count,
               :gsuite_account_domain, :sender_name, :about_section, :milestone_section, :values_section, :team_section,
               :onboard_class_section, :welcome_section, :preboarding_section, :notifications_enabled, :operation_contact_id,
               :default_country, :default_currency, :login_type, :calendar_permissions, :preboard_people_settings, :links_enabled,
               :send_notification_before_start, :team_digest_email, :display_name_format, :default_email_format,
               :sa_disable, :intercom_feature_flag, :zendesk_admin_feature_flag, :smart_assignment_2_feature_flag, :is_service_now_enabled

    has_many :milestones
    has_one :operation_contact, serializer: UserSerializer::Owner
    has_one :organization_root, serializer: UserSerializer::Owner
    has_many :pending_hires, if: Proc.new { |u| (u.scope[:current_user].blank? || u.scope[:current_user].present? && ::PermissionService.new.onlyCheckAdminCanViewAndEditVisibility(u.scope[:current_user], 'dashboard')) }
    has_many :company_links
    has_many :company_values
    has_one :display_logo_image
    has_one :landing_page_image
    has_many :gallery_images

    def plauralize_department
      object.department.pluralize
    end

    def google_auth_enable
      object.integration_instances.find_by(api_identifier: "google_auth", state: :active).active? rescue nil
    end

    def show_adfs_link
      begin
        integration = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active)
        object.authentication_type == 'active_directory_federation_services' and integration.present? and integration.saml_certificate.present? and integration.identity_provider_sso_url.present?
      rescue Exception => e
      end
    end

    def gsuite_account_domain
      if object.get_gsuite_account_info.present?
        object.get_gsuite_account_info.gsuite_account_url
      else
        " "
      end
    end

    def adfs_sso_link
      url = ''
      begin
        if show_adfs_link
          url = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active).identity_provider_sso_url
        end
      rescue Exception => e
      end
      url
    end

    def custom_tables_count
      object.get_cached_custom_tables_count
    end

    def is_service_now_enabled
      object.is_service_now_enabled?
    end
  end
end
