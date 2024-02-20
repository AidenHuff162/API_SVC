FactoryGirl.define do
  factory :milestone do
    name { Faker::Company.buzzword }
    description { Faker::Company.catch_phrase }
    happened_at { Faker::Date.backward }
    milestone_image { build(:milestone_image) }

    company
  end
end
