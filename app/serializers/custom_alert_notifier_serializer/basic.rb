module CustomAlertNotifierSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :notifiable_id, :notifiable_type
  end
end
