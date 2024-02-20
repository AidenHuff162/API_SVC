module UserSerializer
  class Company < ActiveModel::Serializer
    attributes :state, :location_id, :team_id
  end
end
