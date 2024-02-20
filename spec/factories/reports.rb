FactoryGirl.define do
  factory :report do
		name { Faker::Name.first_name }
		company
  end
end
