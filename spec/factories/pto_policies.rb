FactoryGirl.define do
  factory :pto_policy do
    company
    deleted_at { }
    factory :default_pto_policy do
      rate_acquisition_period 4
      accrual_frequency 1
      has_max_accrual_amount false
      allocate_accruals_at 1
      start_of_accrual_period 0
      accrual_renewal_time 1
      first_accrual_method 0
      carry_over_unused_timeoff true
      has_maximum_carry_over_amount false
      can_obtain_negative_balance true
      maximum_negative_amount 1024
      manager_approval true
      tracking_unit 1
      half_day_enabled true
      accrual_rate_unit 0
      accrual_rate_amount 1
      is_enabled true
      unlimited_policy false
      for_all_employees true
      working_hours 8
      working_days ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      after(:create) do |policy|
        policy.approval_chains << create(:pto_approval_chain)
      end
    end
    accrual_renewal_date Date.today.beginning_of_year
    name { Faker::Name.name }
    icon { "icon-briefcase" }
    policy_type { 1 }
    for_all_employees {true}
    filter_policy_by {{"teams": ["all"], "location": ["all"], "employee_status": ["all"]}}
    trait :policy_for_some_employees do
      for_all_employees {false}
      filter_policy_by {{"teams": ["all"], "location": ["101"], "employee_status": ["all"]}}
    end
    is_enabled { true }
    trait :policy_with_expiry_carryover do
      expire_unused_carryover_balance {true}
      carryover_amount_expiry_date {Date.today}
    end

    trait :policy_with_negative_carryover_without_max_carryover do
      carry_over_unused_timeoff {true}
      has_maximum_carry_over_amount {false}
      carry_over_negative_balance {true}
    end

    trait :policy_with_negative_carryover_with_max_carryover do
      carry_over_unused_timeoff {true}
      carry_over_negative_balance {true}
      has_maximum_carry_over_amount {true}
      maximum_carry_over_amount {1}
    end

    trait :policy_without_negative_carryover_without_max_carryover do
      carry_over_unused_timeoff {true}
      has_maximum_carry_over_amount {false}
      carry_over_negative_balance {false}
    end

    trait :policy_without_negative_carryover_with_max_carryover do
      carry_over_unused_timeoff {true}
      has_maximum_carry_over_amount {true}
      maximum_carry_over_amount {1}
      carry_over_negative_balance {false}
    end

    trait :policy_without_carryover do
      carry_over_unused_timeoff {false}
    end

    trait :accruals_at_start do 
      allocate_accruals_at 0
    end

    trait :policy_has_stop_accrual_date do
      accrual_renewal_time 0
      has_stop_accrual_date {true}
      stop_accrual_date 60
    end
  end

end
