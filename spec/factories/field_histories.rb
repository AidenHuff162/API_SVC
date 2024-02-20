FactoryGirl.define do

  factory :field_history do
    field_name { Faker::Company.buzzword }
    new_value { Faker::Name.first_name }
    field_changer { build(:user) }
    field_type 1
    trait :history_of_custom_field do
      custom_field_id { Faker::Number.between(1, 10) }
    end
    trait :history_created_by_integration do
      integration_id { Faker::Number.between(1, 10) }
      field_changer nil
    end
    trait :field_history_for_ssn do
      new_value '000-00-0000'
      custom_field { build(:custom_field, :ssn_field) }
    end
  end

end
