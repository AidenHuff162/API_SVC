module CtusApprovalChainSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :request_state
  end
end
