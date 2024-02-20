FactoryGirl.define do
  factory :pending_hire do

  	first_name { Faker::Name.first_name }
  	last_name { Faker::Name.last_name }
  	personal_email { Faker::Internet.email }
    state 'active'
    phone_number nil
  	
  	company

  	factory :incomplete_pending_hire, parent: :pending_hire do
  		user
  	end
  end
end
