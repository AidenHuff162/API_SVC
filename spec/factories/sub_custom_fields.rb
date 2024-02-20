FactoryGirl.define do
  factory :sub_custom_field do
    name {Faker::Company.name}

    custom_field
    
    factory :country_code_sub_custom_field, parent: :sub_custom_field do
      transient do
        user { nil }
      end
      trait :with_value do 
        after(:create) do |sub_custom_field, object|
          create(:custom_field_value, sub_custom_field: sub_custom_field, value_text: 'PAK', user: object.user)
        end
      end
    end

    factory :area_code_sub_custom_field, parent: :sub_custom_field do
      transient do
        user { nil }
      end
      trait :with_value do 
        after(:create) do |sub_custom_field, object|
          create(:custom_field_value, sub_custom_field: sub_custom_field, value_text: '300', user: object.user)
        end
      end
    end

    factory :phone_sub_custom_field, parent: :sub_custom_field do
      transient do
        user { nil }
      end
      trait :with_value do 
        after(:create) do |sub_custom_field, object|
          create(:custom_field_value, sub_custom_field: sub_custom_field, value_text: '1111111', user: object.user)
        end
      end
    end

    factory :currency_code_sub_custom_field, parent: :sub_custom_field do
      transient do
        user { nil }
      end
      trait :with_value do 
        after(:create) do |sub_custom_field, object|
          create(:custom_field_value, sub_custom_field: sub_custom_field, value_text: 'USD', user: object.user)
        end
      end
    end


    factory :currency_value_sub_custom_field, parent: :sub_custom_field do
      transient do
        user { nil }
      end      
      trait :with_value do 
        after(:create) do |sub_custom_field, object|
          create(:custom_field_value, sub_custom_field: sub_custom_field, value_text: 200, user: object.user)
        end
      end
    end
  end
end
