FactoryGirl.define do
  factory :assigned_pto_policy do
  	carryover_balance {0}
    deleted_at {}
    user
    pto_policy
  end
end
