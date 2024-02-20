FactoryGirl.define do
  factory :approval_chain do
    approval_type ApprovalChain.approval_types[:manager]
    approval_ids ['1']
  end
  
  factory :pto_approval_chain , parent: :approval_chain do
    approval_ids []
  end
end
