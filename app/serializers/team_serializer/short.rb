module TeamSerializer
  class Short < ActiveModel::Serializer
    attributes :id, :name, :users_count, :owner_id, :description, :people_count

    def people_count
      object.get_cached_people_count
    end
  end
end
