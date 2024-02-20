module UserSerializer
  class Owner < Basic
    attributes :start_date, :title, :email, :personal_email, :full_name, :full_image, :preferred_full_name
    has_one :profile
    def full_image
      object.profile_image.file_url if object.profile_image
    end
  end
end
