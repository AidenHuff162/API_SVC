FactoryGirl.define do
  factory :holiday do
  	begin_date { 10.days.from_now.to_date }
  	end_date { 12.days.from_now.to_date }
  	name { Faker::Name.name }
  	team_permission_level {["all"]}
  	status_permission_level {["all"]}
  	location_permission_level {["all"]}
  	multiple_dates {false}
  	company
    
  end
end