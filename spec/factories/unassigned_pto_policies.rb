FactoryGirl.define do
  factory :unassigned_pto_policy do
    starting_balance { Faker::Commerce.price }
    user
    pto_policy
    
  end
end
