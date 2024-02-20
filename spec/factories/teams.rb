FactoryGirl.define do
  factory :team do
    name { Faker::Team.name }
    description { Faker::Hipster.sentence }
    company
    users_count { Faker::Number.between(1, 10) }
    owner { build(:user) }

  end
end
