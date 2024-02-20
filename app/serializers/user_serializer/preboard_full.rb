module UserSerializer
  class PreboardFull < Base
    attributes :id, :title, :role, :state, :picture, :onboard_email,:email, :start_date,
              :team_id, :location_id, :manager_id, :employee_type, :buddy_id,
              :current_stage, :personal_email, :preboarding_progress,
              :preboarding_invisible_field_ids, :team_name, :location_name, :company_name,
              :location, :display_name_format, :created_at, :team, :uid,
              :display_name, :date_of_birth

    has_one :manager, serializer: UserSerializer::Basic
    has_one :buddy, serializer: UserSerializer::Basic
    has_one :profile
    has_one :profile_image

    def team
      object.get_cached_team
    end

    def location
      object.get_cached_location
    end

    def team_name
      object.get_team_name
    end

    def company_name
      object.company.name
    end

    def display_name_format
      object.company.display_name_format
    end

    def employee_type
      object.employee_type
    end

  end
end
