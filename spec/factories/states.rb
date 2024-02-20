FactoryGirl.define do
  factory :state do
    name { Faker::Hipster.word }
    key { Faker::Hipster.word }
    State
  end
 
  factory :alabama, parent: :state do
    name 'AL'
  end
 
  factory :new_york, parent: :state do
    name 'NY'
  end
end