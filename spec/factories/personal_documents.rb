FactoryGirl.define do
  factory :personal_document do

    title { Faker::Name.name }
    description { Faker::Hipster.sentence }
    created_by_id nil
    
    user
  end
end
