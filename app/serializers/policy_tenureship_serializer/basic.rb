module PolicyTenureshipSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :pto_policy_id, :year, :amount
  end
end
