FactoryGirl.define do
  factory :calendar_feed do
    feed_type Faker::Number.between(0, 6)
    user
    company    
  end

  factory :start_date_feed, parent: :calendar_feed do
    feed_type 0
  end

  factory :birthday_calendar_feed, parent: :calendar_feed do
    feed_type 1
  end

  factory :over_due_activities_feed, parent: :calendar_feed do
    feed_type 2
  end

  factory :offboarding_calendar_feed, parent: :calendar_feed do
    feed_type 3
  end

  factory :anniversary_calendar_feed, parent: :calendar_feed do
    feed_type 4
  end

  factory :out_of_office_calendar_feed, parent: :calendar_feed do
    feed_type 5
  end

  factory :holiday_calendar_feed, parent: :calendar_feed do
    feed_type 6
  end
end
