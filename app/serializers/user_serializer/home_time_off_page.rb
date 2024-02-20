module UserSerializer
  class HomeTimeOffPage < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :preferred_full_name, :company_name, :title, :picture,
               :start_date, :location_id, :team_id, :employee_type, :role, :managed_users_count, :manager_id,
               :current_stage, :state, :pto_policies, :termination_date, :last_day_worked, :location,
               :show_manaul_assignment_link, :team, :date_of_birth, :calendar_prefrences, :maximum_year,
               :header_phone_number, :email, :personal_email, :show_performance_tabs, :pto_status, :super_user

    has_one :manager, serializer: UserSerializer::PeopleTeamManager
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

    def pto_policies
      ActiveModelSerializers::SerializableResource.new(object.pto_policies.order(name: :asc),
                                                       each_serializer: PtoPolicySerializer::Basic, object: object,
                                                       parent_serlaizer: 'home_time_off')
    end

    def managed_users_count
      object.cached_managed_user_ids.length
    end

    def show_manaul_assignment_link
      object.count_of_policies_not_assigned_to_user > 0
    end

    def date_of_birth
      object.date_of_birth
    end

    def maximum_year
      company = object.company
      if company.enabled_time_off
        year = object.pto_requests.order('begin_date desc').take.try(:begin_date).try(:year)
        return year.present? && year > company.time.year ? year : company.time.year
      end
    end

    def pto_status
      object.pto_status
    end
  end
end
