FactoryGirl.define do
  factory :calendar_event do
  	event_start_date { 5.days.from_now.to_date }
  	event_end_date { 5.days.from_now.to_date }
  	eventable_type "User"
  	color 2
  	trait :pto_event do
  		eventable_type "PtoRequest"
  		color nil
  	end
  end
end
