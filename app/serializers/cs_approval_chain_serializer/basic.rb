module CsApprovalChainSerializer
  class Basic < ActiveModel::Serializer
    attributes :id, :state, :approver_id, :approval_date
  end
end
