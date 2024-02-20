module UserSerializer
  class HomeUpdatesPage < UpdatesPage
    attributes :state, :manager_id, :email, :personal_email, :start_date, :title, :role, :termination_date,
               :last_day_worked, :managed_users_count, :current_stage, :pto_policies, :team, :location, :date_of_birth,
               :calendar_prefrences, :header_phone_number, :show_performance_tabs, :employee_type, :team_id,
               :location_id, :managed_users_ids, :indirect_reports_ids, :managed_approval_chain_users_ids, :pto_status,
               :display_name, :super_user, :ui_switcher

    has_one :manager, serializer: UserSerializer::UpdatesPage
    has_one :profile_image
    has_one :user_role, serializer: UserRoleSerializer::Basic

    def pto_policies
      if scope[:include_pto_policies] && scope[:include_pto_policies].present? && object.company.enabled_time_off
        ActiveModelSerializers::SerializableResource.new(object.pto_policies, each_serializer: PtoPolicySerializer::Updates, object: object)
      else
        []
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
