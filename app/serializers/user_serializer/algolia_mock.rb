module UserSerializer
  class AlgoliaMock < ActiveModel::Serializer
    attributes :first_name, :last_name, :title, :company_id, :location_id, :team_id, :preferred_name, :picture, :objectID, :preferred_full_name

    def objectID
      object.id
    end
  end
end
