FactoryGirl.define do
  factory :comment do
    description {Faker::Hipster.sentence}
    commentable_id {nil}
    mentioned_users []
    company
  end
end
