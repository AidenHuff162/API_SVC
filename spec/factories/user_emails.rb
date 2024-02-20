FactoryGirl.define do
  factory :user_email do
    subject { Faker::Name.first_name }
    cc { Faker::Name.first_name+'@test.com' }
    bcc { Faker::Name.first_name+'@test.com' }
    description { Faker::Lorem.sentence }
    user
  end
end
