FactoryGirl.define do
  factory :pto_adjustment do
    hours 1
    operation 1
    description "MyString"
    effective_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date
    trait :applied_adjustment_current_year do
      is_applied true
      effective_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date
    end
    trait :applied_adjustment_past_year do
      effective_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_year - 5.days
    end
    trait :applied_adjustment_of_past do
      is_applied true
      effective_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date - 1.days
    end
    trait :applied_adjustment_of_same_year do
      is_applied true
      effective_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_year
    end
    assigned_pto_policy nil
    trait :past_adjustment do
      effective_date (DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date - 1.days)
    end
    trait :future_adjustment do
      effective_date (DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date + 1.days)
    end
  end
end
