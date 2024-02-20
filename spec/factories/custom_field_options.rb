FactoryGirl.define do
  factory :custom_field_option do
    trait :gender_male do
      option 'Male'
    end
    custom_field

  end

  factory :rate_type, parent: :custom_field_option do
    adp_wfn_us_code_value :test
  end   
end
