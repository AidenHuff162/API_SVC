FactoryGirl.define do
  factory :api_key do
    name { Faker::Name.name }
    key { Faker::Bitcoin.address }
  end
end
