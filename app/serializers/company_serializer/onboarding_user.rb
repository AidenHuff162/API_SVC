module CompanySerializer
  class OnboardingUser < ActiveModel::Serializer
    attributes :id, :prefrences, :buddy, :phone_format, :integration_type, :integration_types, :name, :singular_department, :is_namely_integrated,
               :enable_gsuite_integration, :gsuite_account_exists, :is_jira_enabled, :account_domain, :default_country,
               :default_currency, :time_zone, :time_zone_options, :ats_integration_types, :asana_integration_enabled, :link_gsuite_personal_email,
               :adp_templates_enabled, :team_digest_email, :display_name_format, :default_email_format, :subdomain,
               :custom_fields, :provisioning_integration_type, :provisiong_account_exists, :adp_company_code_enabled,
               :adp_us_company_code_enabled, :adp_can_company_code_enabled, :bulk_onboarding_feature_flag, :account_type,
               :from_email_list, :google_groups_feature_flag, :surveys_enabled, :sa_disable, :intercom_feature_flag, :limited_sandbox_access, 
               :survey_paywall_feature_flag, :smart_tasks_assignments_feature_flag, :email_rebranding_feature_flag, :company_plan, :adp_v2_migration_feature_flag,
               :zendesk_admin_feature_flag, :company_trial_feature_flag, :smart_assignment_2_feature_flag, :smart_assignment_configuration, :is_service_now_enabled,
               :ui_switcher_feature_flag, :adp_zip_validations_feature_flag, :promo_relo_mvp_feature_flag

    has_one :billing, serializer: BillingSerializer

    def custom_fields
      ActiveModelSerializers::SerializableResource.new(object.custom_fields, each_serializer: CustomFieldSerializer::Basic)
    end

    def time_zone_options
      ActiveSupport::TimeZone.all.map { |tz| {id: tz.name, utc_offset: 'UTC' + tz.formatted_offset } }
    end

    def custom_fields
      ActiveModelSerializers::SerializableResource.new(object.custom_fields, each_serializer: CustomFieldSerializer::Basic)
    end

    def account_domain
      if object.provisiong_account_exists?
        object.provisioning_integration_url
      else
        " "
      end
    end

    def provisiong_account_exists
      object.provisiong_account_exists?
    end

    def from_email_list
      default_email = "#{current_user.company.sender_name} (#{current_user.company.subdomain}@#{ENV['DEFAULT_HOST']})"
      if current_user.email.present?
        ["#{current_user.full_name} (#{current_user.email})", default_email]
      else
        [default_email]
      end
    end

    def smart_assignment_configuration
      ActiveModelSerializers::SerializableResource.new(object.smart_assignment_configuration, serializer: SmartAssignmentConfigurationSerializer::Basic) if object&.smart_assignment_configuration
    end

    def is_service_now_enabled
      object.is_service_now_enabled?
    end
  end
end
