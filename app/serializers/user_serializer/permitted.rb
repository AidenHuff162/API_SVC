module UserSerializer
  class Permitted < Base
    include Workspaces

    attributes :id, :email, :title, :picture, :pto_policies, :home_group_name, :profile_permissions, :show_performance_tabs,
      :company_name, :user_role_name, :last_active, :team_id, :team, :onboarding_profile_template, :managed_users_count,
      :is_form_completed_by_manager, :location, :start_date, :user_has_documents, :workspaces, :personal_email, :termination_date,
      :termination_type, :last_day_worked, :eligible_for_rehire, :location_id, :employee_type, :state, :role, :user_role_id, :onboarding_profile_template_id,
      :managed_users_ids, :indirect_reports_ids, :managed_approval_chain_users_ids, :custom_section_approvals, :manager_id,
      :pto_status, :buddy_id

    has_one :profile, serializer: ProfileSerializer::Permitted
    has_one :user_role, serializer: UserRoleSerializer::Basic
    has_one :manager, serializer: UserSerializer::Simple
    has_one :buddy, serializer: UserSerializer::Minimal

    def company_name
      object.company.name
    end

    def pto_policies
      if scope[:include_pto_policies] && scope[:include_pto_policies].present? && object.company.enabled_time_off
        ActiveModelSerializers::SerializableResource.new(object.pto_policies, each_serializer: PtoPolicySerializer::Updates, object: object)
      else
        []
      end
    end

    def custom_section_approvals
      return [] if !instance_options[:approval_profile_page] || object.requested_custom_section_approvals.count == 0
      ActiveModelSerializers::SerializableResource.new(object.requested_custom_section_approvals, each_serializer: CustomSectionApprovalSerializer::Basic)
    end
    
    def team
      object.get_cached_team
    end

    def home_group_name
      object.company.group_for_home == "Department" ? nil : object.get_custom_field_value_text(object.company.group_for_home)
    end

    def profile_permissions
      if scope[:profile_permissions]
        scope[:profile_permissions]
      end
    end

    def user_has_documents
      object.user_has_documents?
    end

    def user_role_name
      object.get_cached_role_name(instance_options[:approval_profile_page])
    end

    def onboarding_profile_template
      if scope[:include_onboarding_template] && object.onboarding_profile_template
        ActiveModelSerializers::SerializableResource.new(object.onboarding_profile_template, serializer: ProfileTemplateSerializer::WithConnections)
      else
        nil
      end
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def personal_email
      object.personal_email if object.access_field_permission_service(scope[:current_user], object, object.company, 'Personal Email')
    end

    def termination_date
      object.termination_date if object.access_field_permission_service(scope[:current_user], object, object.company, 'Termination Date')
    end

    def termination_type
      object.termination_type if object.access_field_permission_service(scope[:current_user], object, object.company, 'Termination Type')
    end

    def last_day_worked
      object.last_day_worked if object.access_field_permission_service(scope[:current_user], object, object.company, 'Last Day Worked')
    end

    def eligible_for_rehire
      object.eligible_for_rehire if object.access_field_permission_service(scope[:current_user], object, object.company, 'Eligible for Rehire')
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
