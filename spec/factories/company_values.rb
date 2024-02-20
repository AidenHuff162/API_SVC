FactoryGirl.define do
  factory :company_value do
    name { Faker::Company.buzzword }
    description { Faker::Company.catch_phrase }

    company
  end
end
