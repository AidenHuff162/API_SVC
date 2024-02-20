FactoryGirl.define do
  factory :company_link do
    link { Faker::Internet.url }
    name { Faker::Hipster.word }
    company
  end
end
