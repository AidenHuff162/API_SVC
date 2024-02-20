module UserSerializer
  class HomeProfilePage < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :preferred_full_name, :company_name, :title, :picture,
               :start_date, :location_id, :team_id, :email, :personal_email, :user_role_id, :employee_type,
               :user_role_name, :role, :managed_users_count, :manager_id, :current_stage, :state, :job_tier,
               :termination_date, :last_day_worked, :termination_type, :eligible_for_rehire, :paylocity_id, :buddy_id,
               :fields_last_modified_at, :team, :location, :profile_permissions, :last_active, :onboard_email,
               :home_group_name, :date_of_birth, :calendar_prefrences, :header_phone_number, :show_performance_tabs,
               :trinet_id, :onboarding_profile_template_id, :managed_users_ids, :indirect_reports_ids,
               :managed_approval_chain_users_ids, :custom_section_approvals, :display_name, :pto_status, :super_user,
               :adp_onboarding_template, :working_pattern_id

    has_one :manager, serializer: UserSerializer::Simple
    has_one :buddy, serializer: UserSerializer::Minimal
    has_one :profile, serializer: ProfileSerializer::Permitted
    has_one :profile_image
    has_one :user_role, serializer: UserRoleSerializer::Basic
    has_one :offboarding_profile_template, serializer: ProfileTemplateSerializer::ProfilePage
    has_one :onboarding_profile_template, serializer: ProfileTemplateSerializer::ProfilePage

    def company_name
      object.company.name
    end

    def custom_section_approvals
      return [] if !instance_options[:approval_profile_page] || object.requested_custom_section_approvals.count == 0
      ActiveModelSerializers::SerializableResource.new(object.requested_custom_section_approvals, each_serializer: CustomSectionApprovalSerializer::Basic)
    end

    def team
      object.get_cached_team
    end

    def location
      object.get_cached_location
    end

    def home_group_name
      object.company.group_for_home == "Department" ? nil : object.get_custom_field_value_text(object.company.group_for_home)
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def employee_type
      object.employee_type
    end

    def user_role_name
      object.get_cached_role_name(instance_options[:approval_profile_page])
    end

    def profile_permissions
      if scope[:profile_permissions]
        scope[:profile_permissions]
      end
    end

    def date_of_birth
      object.date_of_birth
    end

    def managed_users_ids
      object.cached_managed_user_ids
    end

    def indirect_reports_ids
      object.cached_indirect_reports_ids
    end

    def managed_approval_chain_users_ids
      object.managed_approval_chain_users&.pluck(:id)
    end

    def pto_status
      object.pto_status
    end
  end
end
