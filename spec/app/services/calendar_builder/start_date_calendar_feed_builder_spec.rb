require 'rails_helper'

RSpec.describe CalendarBuilder::StartDateCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:hilda, company: company) }
  let(:calendar_feed) { create(:start_date_feed, user: user, company: company) }
  let(:calendar_feed_nil) { create(:start_date_feed, user: nil, company: company) }

  context 'with offboarding feed calendar spec' do
    let(:start_date_feed) { described_class.new(calendar_feed).call }
    let(:start_date_feed_nil) { described_class.new(calendar_feed_nil).call }

    it 'should check offboarding feed calendar name' do
      expect(start_date_feed[:calendar_name]).to eq("New Hire Starts for #{company.name}")
    end

    it 'should check start_date in calendar event of offboarding calendar feed' do
      expect(start_date_feed[:calendar_events][0][:dtstart]).to eq(user.start_date)
    end

    it 'should check summary in calendar event of offboarding calendar feed' do
      expect(start_date_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check description in calendar event of offboarding calendar feed' do
      expect(start_date_feed[:calendar_events][0][:description]).not_to be_empty
    end

    it 'should check offboarding calender event is nil' do
      expect(start_date_feed_nil[:calendar_events]).to be_empty
    end
  end
end

