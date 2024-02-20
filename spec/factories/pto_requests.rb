FactoryGirl.define do
  factory :pto_request do
    factory :default_pto_request do
      partial_day_included false
      begin_date DateTime.now
      end_date   DateTime.now
      status     0
      balance_hours 8
      trait :partial_day_request do
        begin_date DateTime.new(Date.today.year, Date.today.month,  Date.today.day, 13, 0, 0)
        end_date   DateTime.new(Date.today.year, Date.today.month,  Date.today.day, 13, 30, 0)
      end
      trait :request_with_multiple_days do
        begin_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_week
        end_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_week + 8.days
      end
      trait :denied_request_for_one_year_in_past do
        status 2
        begin_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_year - 11.days
        end_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date.beginning_of_year - 1.days
      end
      trait :denied_request_for_the_present_year do
        status 2
        begin_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date
        end_date DateTime.now.utc.in_time_zone("Pacific Time (US & Canada)").to_date
      end
      trait :approved_pto_request do
        status     1
      end
      trait :denied_pto_request do
        status     2
      end

      factory :pto_request_skip_send_email_callback do
        after(:build) { |pto_request| pto_request.class.skip_callback(:create, :after, :send_email_to_respective_role, raise: false) }
      end
    end
  end
end
