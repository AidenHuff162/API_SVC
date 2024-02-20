module UserSerializer
  class PtoAdjustmentCreator < ActiveModel::Serializer
    attributes :picture, :preferred_full_name, :last_name, :preferred_name, :first_name
  end
end
