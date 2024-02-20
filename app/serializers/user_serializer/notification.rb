module UserSerializer
  class Notification < ActiveModel::Serializer
    attributes :id, :slack_notification, :email_notification

  end
end