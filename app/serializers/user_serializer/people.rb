module UserSerializer
  class People < Basic
    attributes :full_name, :picture, :title, :state, :email, :team_name, :manager_name, :medium_picture, :location_name, :location_id, :team_id, :current_stage,
     :employee_type, :preferred_full_name, :start_date, :last_day_worked, :user_role, :managed_users_ids, :indirect_reports_ids
    belongs_to :manager, serializer: UserSerializer::Basic

    def full_name
      object.preferred_full_name
    end

    def title
      object.title.gsub('&amp;amp;', '&') if object.title.present?
      object.title.gsub('&amp;', '&') if object.title.present?
    end

    def team_name
      object.get_team_name
    end

    def manager_name
      object.manager.full_name if object.manager
    end

    def location_name
      object.get_location_name
    end

    def employee_type
      object.employee_type
    end

    def user_role
      object.user_role
    end

    def managed_users_ids
      object.managed_user_ids
    end

    def indirect_reports_ids
      object.indirect_reports_ids
    end
  end
end
