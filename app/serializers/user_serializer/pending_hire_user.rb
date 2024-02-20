module UserSerializer
  class PendingHireUser < ActiveModel::Serializer
    attributes :id, :current_stage, :last_day_worked
  end
end
