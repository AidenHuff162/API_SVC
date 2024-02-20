module UserSerializer
  class Home < Basic
    attributes :is_onboarding, :state, :manager_id, :email, :personal_email, :start_date, :job_tier, :title, :role,
               :termination_date, :last_day_worked, :termination_type, :eligible_for_rehire, :buddy_id, :team_id,
               :location_id, :picture, :managed_users_count, :current_sign_in_at, :fields_last_modified_at,
               :current_stage, :employee_type, :user_role_name, :user_role_id, :pto_policies, :user_has_documents,
               :paylocity_id, :team, :location, :is_form_completed_by_manager, :date_of_birth, :calendar_prefrences,
               :header_phone_number, :onboarding_profile_template, :show_performance_tabs, :pto_status, :super_user,
               :ui_switcher, :working_pattern_id

    has_one :manager, serializer: UserSerializer::People
    has_one :buddy, serializer: UserSerializer::Basic
    has_one :profile_image
    has_one :profile, serializer: ProfileSerializer::Permitted
    has_one :user_role, serializer: UserRoleSerializer::Basic

    def pto_policies
      if scope[:include_pto_policies] && scope[:include_pto_policies].present? && object.company.enabled_time_off
        ActiveModelSerializers::SerializableResource.new(object.pto_policies, each_serializer: PtoPolicySerializer::Updates, object: object)
      else
        []
      end
    end

    def onboarding_profile_template
      if scope[:include_onboarding_template] && object.onboarding_profile_template
        ActiveModelSerializers::SerializableResource.new(object.onboarding_profile_template, serializer: ProfileTemplateSerializer::WithConnections)
      else
        nil
      end
    end

    def team
      object.get_cached_team
    end

    def location
      object.get_cached_location
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def is_onboarding
      object.onboarding?
    end

    def employee_type
      object.employee_type
    end

    def include_pto_policies
      scope[:include_pto_policies].present? and scope[:include_pto_policies] == true
    end

    def user_role_name
      object.get_cached_role_name
    end

    def user_has_documents
      object.user_has_documents?
    end

    def date_of_birth
      object.date_of_birth
    end

    def pto_status
      object.pto_status
    end
  end
end
