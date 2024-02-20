module HistoryUserSerializer
  class Base < ActiveModel::Serializer
    attributes :id, :user
    # belongs_to :user, serializer: UserSerializer::HistoryUser

    def user
      related_user = object.try(:user)
      if related_user.present?
        {
          first_name: related_user.first_name,
          last_name: related_user.last_name,
          id: related_user.id,
          picture: related_user.picture
        }
      else
        {}
      end
    end
  end
end
