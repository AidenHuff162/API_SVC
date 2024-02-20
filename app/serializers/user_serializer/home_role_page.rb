module UserSerializer
  class HomeRolePage < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :preferred_full_name, :company_name, :title, :picture,
               :start_date, :location_id, :team_id, :employee_type, :role, :managed_users_count, :manager_id,
               :current_stage, :termination_date, :last_day_worked, :termination_type, :eligible_for_rehire, :location,
               :state, :team, :date_of_birth, :calendar_prefrences, :header_phone_number, :email, :personal_email,
               :show_performance_tabs, :display_name, :pto_status, :super_user

    has_one :manager, serializer: UserSerializer::PeopleTeamManager
    has_one :profile_image
    has_one :onboarding_profile_template, serializer: ProfileTemplateSerializer::ProfilePage
    has_one :offboarding_profile_template, serializer: ProfileTemplateSerializer::ProfilePage
    has_one :user_role, serializer: UserRoleSerializer::Basic

    def company_name
      object.company.name
    end

    def employee_type
      object.employee_type
    end

    def location
      object.get_cached_location
    end

    def team
      object.get_cached_team
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def date_of_birth
      object.date_of_birth
    end

    def pto_status
      object.pto_status
    end
  end
end
