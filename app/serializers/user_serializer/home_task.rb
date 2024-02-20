module UserSerializer
  class HomeTask < ActiveModel::Serializer
    attributes :id, :picture, :preferred_full_name, :last_name, :preferred_name, :first_name, :start_date, :title, :email, :personal_email
  end
end
