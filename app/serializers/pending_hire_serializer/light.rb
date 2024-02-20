module PendingHireSerializer
  class Light < ActiveModel::Serializer
    type :pending_hire

    attributes :id, :name, :title, :team_name, :location_name, :manager_name,
      :start_date, :user_id, :duplication_type, :employee_type
      
    has_one :user, serializer: UserSerializer::PendingHireUser
    has_one :location, serializer: LocationSerializer::Short
    has_one :team, serializer: TeamSerializer::Short

    def name
      object.company.global_display_name(object, object.company.display_name_format)
    end

    def team_name
      object.team.name if object.team
    end

    def location_name
      object.location.name if object.location
    end

    def manager_name
      object.manager.full_name if object.manager
    end

    def start_date
      begin
        object.start_date.present? ? Time.parse(object.start_date).to_date.to_s : ""
      rescue
        object.start_date.present? ? object.start_date : ""
      end
    end
  end
end
