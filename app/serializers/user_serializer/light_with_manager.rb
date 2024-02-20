module UserSerializer
  class LightWithManager < Base
    attributes :id, :title, :location_name, :picture
    has_one :profile_image
    has_one :manager, serializer: UserSerializer::Light

    def location_name
      object.get_location_name
    end
  end
end
