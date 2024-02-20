require 'rails_helper'

RSpec.describe CalendarBuilder::BirthdayCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:user_nil) { create(:user, company: company) }
  let(:custom_field) { create(:custom_field, :date_of_birth, company: company) }
  let(:custom_field_value) { create(:custom_field_value, :date_of_birth, custom_field: custom_field, user: user) }
  let(:calendar_feed) { create(:birthday_calendar_feed, user: user, company: company) }
  let(:calendar_feed_nil) { create(:birthday_calendar_feed, user: user_nil, company: company) }

  context 'with birthday feed calendar' do
    let(:birthday_feed) { described_class.new(calendar_feed).call }
    let(:birthday_feed_nil) { described_class.new(calendar_feed_nil).call }


    it 'should check calendar name of birthday calendar feed' do
      custom_field
      custom_field_value
      expect(birthday_feed[:calendar_name]).to eq('Birthday Calendar')
    end

    it 'should check birthday calendar feed event summary' do
      custom_field
      custom_field_value
      date_of_birth = user.date_of_birth.to_date
      expect(birthday_feed[:calendar_events][0][:dtstart])
        .to eq(Date.parse("#{Time.zone.today.year}-#{date_of_birth.month}-#{date_of_birth.day}"))
    end

    it 'should check birthday calendar feed event summary' do
      custom_field
      custom_field_value
      expect(birthday_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should birthday calendar feed event description' do
      custom_field
      custom_field_value
      expect(birthday_feed[:calendar_events][0][:description]).not_to be_empty
    end

    it 'should check calendar event will be empty' do
      expect(birthday_feed_nil[:calendar_events]).to be_empty
    end
  end
end
