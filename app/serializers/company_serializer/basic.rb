module CompanySerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :logo, :custom_tables_count, :authentication_type, :show_saml_login_button,
               :enabled_calendar, :show_adfs_link, :adfs_sso_link, :date_format, :timeout_interval, :enabled_time_off,
               :enabled_org_chart, :is_using_custom_table , :brand_color, :integration_type, :is_namely_integrated,
               :enable_gsuite_integration, :ats_integration_types, :time_zone_offset, :plauralize_department,
               :is_jira_enabled, :singular_department, :welcome_note, :team_section, :onboard_class_section,
               :preboarding_note, :preboarding_title, :login_type, :pto_events, :org_chart_shareable_link,
               :calendar_permissions, :preboard_people_settings, :created_at, :links_enabled,
               :asana_integration_enabled, :default_currency, :team_digest_email, :history_feature_flag, :time_zone,
               :display_name_format, :get_paperwork_packet_types, :get_document_packet_types,
               :get_upload_request_types, :show_performance_tab, :feedback_feature_flag, :bulk_rehire_feature_flag,
               :sa_disable, :enable_custom_table_approval_engine, :intercom_feature_flag, :limited_sandbox_access,
               :account_type, :survey_paywall_feature_flag, :surveys_enabled, :pto_paywall_feature_flag,
               :profile_approval_feature_flag, :org_paywall_feature_flag, :ohsa_covid_feature_flag, :company_plan,
               :email_rebranding_feature_flag, :adp_v2_migration_feature_flag, :zendesk_admin_feature_flag,
               :smart_tasks_assignments_feature_flag, :company_trial_feature_flag, :smart_assignment_2_feature_flag,
               :smart_assignment_configuration, :is_service_now_enabled, :ui_switcher_feature_flag, 
               :calendar_feed_syncing_feature_flag, :sftp_feature_flag, :ids_authentication_feature_flag,
               :api_data_segmentation_feature_flag, :promo_relo_mvp_feature_flag, :working_patterns_feature_flag, :pto_requests_feature_flag
               
    has_one :operation_contact, serializer: UserSerializer::Preboard
    has_one :billing, serializer: BillingSerializer

    def org_chart_shareable_link
      if scope && scope[:shareable_org_chart].present?
        object.get_org_chart_shareable_url
      else
        nil
      end
    end

    def adfs_sso_link
      url = ''
      if show_adfs_link
        url = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active).identity_provider_sso_url
      end
      url
    end

    def plauralize_department
      object.department.pluralize
    end

    def show_adfs_link
      integration = object.integration_instances.find_by(api_identifier: 'active_directory_federation_services', state: :active)
      object.authentication_type == 'active_directory_federation_services' and integration.present? and integration.saml_certificate.present? and integration.identity_provider_sso_url.present?
    end

    def time_zone_offset
      time = Time.now
      time_zone_offset = (time.in_time_zone(object.time_zone).utc_offset.to_f/1.hour.to_f) * -1
    end

    def custom_tables_count
      object.get_cached_custom_tables_count
    end

    def pto_events
      object.pto_events
    end

    def get_paperwork_packet_types
      object.paperwork_packets.pluck("meta -> 'type'").compact.uniq
    end

    def get_document_packet_types
      object.documents.pluck("meta -> 'type'").compact.uniq
    end

    def get_upload_request_types
      object.document_upload_requests.pluck("meta -> 'type'").compact.uniq
    end

    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end

    def is_service_now_enabled
      object.is_service_now_enabled?
    end
  end
end
