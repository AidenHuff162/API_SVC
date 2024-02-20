FactoryGirl.define do
  factory :history do
    description { Faker::Hipster.sentence }
	description_count 1
  end
end
