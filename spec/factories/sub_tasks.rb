FactoryGirl.define do
  factory :sub_task do
    title { Faker::Hipster.sentence }
    task
  end
end
