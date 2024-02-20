FactoryGirl.define do
  factory :invite do
    subject { Faker::Lorem.sentence }
    description { Faker::Lorem.sentence }
    user_email {build(:user_email)}
  end

  factory :invite_with_user_email, parent: :invite do
    subject { Faker::Lorem.sentence }
    description { Faker::Lorem.sentence }
    user_email
  end
end
