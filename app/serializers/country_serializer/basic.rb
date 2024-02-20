module CountrySerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :name, :subdivision_type, :areacode_type, :city_type, :key

    def key
      object.key.nil? ? object.name : object.key
    end
  end
end
