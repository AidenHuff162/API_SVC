module PaperworkRequestSerializer
  class ActivityOwner < ActiveModel::Serializer
    has_one :user, serializer: UserSerializer::ActivityOwner
  end
end
