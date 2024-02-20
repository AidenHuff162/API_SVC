module UserSerializer
  class PreboardTeamTab < ActiveModel::Serializer
    attributes :first_name, :last_name, :full_name, :preferred_name, :preferred_full_name, :title, :picture, :start_date
  end
end
