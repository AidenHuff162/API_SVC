FactoryGirl.define do
  factory :location do
    name { Faker::Address.city }
    description { Faker::Hipster.sentence }
    company
    users_count { Faker::Number.between(1, 10) }
    owner { build(:user) }
  end
end
