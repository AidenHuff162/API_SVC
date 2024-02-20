module UserSerializer
  class Profile < Base
    attributes :id, :picture

    has_one :profile_image
  end
end
