FactoryGirl.define do
  factory :ctus_approval_chain do
    request_state CtusApprovalChain.request_states[:requested]
  end
end
