module UserSerializer
  class BulkOnboarding < ActiveModel::Serializer
    attributes :id, :first_name, :last_name, :preferred_name, :preferred_full_name,
      :title, :picture, :start_date, :location_id, :team_id, :employee_type,
      :manager_id, :location, :team, :email, :personal_email


    has_one :manager, serializer: UserSerializer::PeopleTeamManager
    has_one :profile_image

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

  end
end
