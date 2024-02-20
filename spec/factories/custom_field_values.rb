FactoryGirl.define do
  factory :custom_field_value do
    value_text {Faker::Company.name}
    trait :belonging_to_subcustom_field do
      sub_custom_field { build(:sub_custom_field) }
    end

    trait :value_of_personal_info_custom_field do
      value_text {Faker::Company.name}
      custom_field { build(:custom_field, :user_info_and_profile_custom_field) }
      sub_custom_field { nil }
      user { build(:user) }
    end

    trait :custom_field_with_user do
      user { create(:user) }
    end

    trait :employee_number_field_value do
      value_text { '12345678' }
    end

    trait :date_of_birth do
      value_text { 'August 19, 1999' }
    end
  end
end
