FactoryGirl.define do
  factory :profile do
    about_you {Faker::Hipster.sentence}
    facebook "fb.com/profile"
    twitter "twitter.com/profile"
    linkedin "linkedin.com/profile"
    github "github.com/profile"
    user {build(:user)}
  end
end
