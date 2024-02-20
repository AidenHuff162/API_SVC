module LocationSerializer
  class People < ActiveModel::Serializer
    attributes :id, :name, :people_count

    def people_count
      UsersCollection.new(people: true, registered: true, location_id: object.id).results.count
    end
  end
end
