module UserSerializer
  class GroupBasic < Basic
    attributes :picture
    has_one :profile_image
  end
end
