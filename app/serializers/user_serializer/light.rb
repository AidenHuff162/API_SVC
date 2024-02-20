module UserSerializer
  class Light < Base
    attributes :id, :picture

    has_one :profile_image
  end
end
