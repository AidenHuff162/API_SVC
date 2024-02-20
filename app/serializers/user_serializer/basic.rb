module UserSerializer
  class Basic < Base
    type :user

    attributes :id, :email, :title, :team_name, :location_name, :picture, :personal_email, :display_first_name, :display_name

    def team_name
      object.get_team_name
    end

    def location_name
      object.get_location_name
    end
  end
end
