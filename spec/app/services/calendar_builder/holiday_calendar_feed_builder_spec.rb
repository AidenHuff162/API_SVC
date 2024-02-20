require 'rails_helper'

RSpec.describe CalendarBuilder::HolidayCalendarFeedBuilder do
  let(:company) { create(:company) }
  let!(:holiday) { create(:holiday, company: company) }
  let(:calendar_feed) { create(:holiday_calendar_feed, company: company) }

  context 'with holiday feed calendar spec' do
    let(:holiday_feed) { described_class.new(calendar_feed).call } 

    it 'should check calendar name of holiday calendar feed' do
      expect(holiday_feed[:calendar_name]).to eq("Holiday Calendar for #{company.name}")
    end

    it 'should check start_date in calendar event of holiday calendar feed' do
      expect(holiday_feed[:calendar_events][0][:dtstart].to_date)
        .to eq(holiday.begin_date)
    end

    it 'should check end_date in calendar event of holiday calendar feed' do
      expect(holiday_feed[:calendar_events][0][:dtend].to_date)
        .to eq(holiday.end_date)
    end

    it 'should check summary in calendar event of holiday calendar feed' do
      expect(holiday_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check description in calendar event of holiday calendar feed' do
      expect(holiday_feed[:calendar_events][0][:description]).not_to be_empty
    end
  end
end

