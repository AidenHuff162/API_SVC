module UserSerializer
  class HomeLight < Basic
    attributes :state, :manager_id, :email, :personal_email, :start_date, :title, :role, :buddy_id, :team_id,
               :location_id, :termination_date, :picture, :last_day_worked, :managed_users_count, :company_name,
               :employee_type, :current_stage, :team, :location, :date_of_birth, :calendar_prefrences,
               :header_phone_number, :show_performance_tabs, :managed_users_ids, :indirect_reports_ids,
               :managed_approval_chain_users_ids, :pto_status, :super_user

    has_one :user_role, serializer: UserRoleSerializer::Basic
    has_one :buddy, serializer: UserSerializer::Basic
    has_one :manager, serializer: UserSerializer::Basic
    has_one :profile_image

    def team
      object.get_cached_team
    end

    def location
      object.get_cached_location
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def company_name
      object.company.name
    end

    def employee_type
      object.employee_type
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
