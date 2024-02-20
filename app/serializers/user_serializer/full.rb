module UserSerializer
  class Full < Short
    attributes :location_id, :team_id, :incomplete_documents_count, :current_stage,
               :created_at, :co_signer_paperwork_count, :google_auth_enable,
               :is_form_completed_by_manager, :managed_users_count, :fields_last_modified_at,
               :managed_users_ids, :preferred_full_name, :custom_field_values_present, :email_notification,
               :slack_notification, :paylocity_id, :team, :last_active, :profile_permissions, :termination_date,
               :provision_gsuite, :send_credentials_type, :send_credentials_time, :send_credentials_offset_before,
               :send_credentials_timezone, :uid, :indirect_reports_ids, :adp_onboarding_template, :display_name, :date_of_birth,
               :onboarding_profile_template_id, :smart_assignment, :last_used_profile_template_id, :trinet_id, :managed_approval_chain_users_ids,
               :working_pattern_id

    has_one :manager, serializer: UserSerializer::Basic
    has_one :buddy, serializer: UserSerializer::Basic
    has_one :user_role, serializer: UserRoleSerializer::Basic
    has_one :pending_hire, serializer: PendingHireSerializer::Basic
    has_one :onboarding_profile_template, serializer: ProfileTemplateSerializer::WithConnections

    def incomplete_documents_count
      object.incomplete_upload_request_count + object.incomplete_paperwork_count
    end

    def team
      object.get_cached_team
    end

    def google_auth_enable
      integration = object.company.integration_instances.find_by(api_identifier: "google_auth", state: :active)
      google_auth_enable = false

      google_auth_enable = true if integration && integration.active?

      google_auth_enable
    end

    def managed_users_count
      object.cached_managed_user_ids.length
      #object.managed_users.count
    end

    def managed_users_ids
      object.cached_managed_user_ids
    end

    def indirect_reports_ids
     object.cached_indirect_reports_ids
    end

    def custom_field_values_present
      object.custom_field_values.present?
    end

    def profile_permissions
      if scope && scope[:profile_permissions]
        scope[:profile_permissions]
      elsif instance_options && instance_options[:profile_permissions]
        instance_options[:profile_permissions]
      end
    end

    def managed_approval_chain_users_ids
      object.managed_approval_chain_users&.pluck(:id)
    end
  end
end
