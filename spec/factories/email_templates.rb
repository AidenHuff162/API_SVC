FactoryGirl.define do
  factory :email_template do
   company
   subject { Faker::Lorem.sentence }
   cc  { Faker::Internet.email }
   bcc { Faker::Internet.email }
   description  { Faker::Lorem.sentence }
   email_type :invitation
   email_to { Faker::Internet.email }
   editor_id 1
   name :Invite
  end

  factory :welcome, parent: :email_template do
   company
   subject { Faker::Lorem.sentence }
   cc  { Faker::Internet.email }
   bcc { Faker::Internet.email }
   description  { Faker::Lorem.sentence }
   email_type :welcome_email
   email_to { Faker::Internet.email }
   editor_id 1
   name :Welcome
  end
end
