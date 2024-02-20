require 'rails_helper'

RSpec.describe CalendarBuilder::AnniversaryCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, start_date: Time.zone.today) }
  let(:user_previous) { create(:user, company: company, start_date: Time.zone.today - 1.year) }
  let(:calendar_feed) { create(:anniversary_calendar_feed, user: user, company: company) }
  let(:calendar_feed_nil) { create(:anniversary_calendar_feed, company: company) }
  let(:calendar_feed_previous) { create(:anniversary_calendar_feed, user: user_previous, company: company) }

  context 'with anniversary feed calendar spec' do
    let(:anniversary_feed) { described_class.new(calendar_feed).call }
    let(:anniversary_feed_nil) { described_class.new(calendar_feed_nil).call }
    let(:anniversary_feed_previous) { described_class.new(calendar_feed_previous).call }

    it 'should check calendar name of anniversary calendar feed' do
      expect(anniversary_feed[:calendar_name]).to eq("Anniversary Calendar for #{company.name}")
    end

    it 'should check start_date in calendar event of anniversary calendar feed' do
      expect(anniversary_feed[:calendar_events][0][:dtstart])
        .to eq((user.start_date + 6.months).strftime('%Y%m%d').to_s)
    end

    it 'should check summary in calendar event of anniversary calendar feed' do
      expect(anniversary_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check description in calendar event of anniversary calendar feed' do
      expect(anniversary_feed[:calendar_events][0][:description]).not_to be_empty
    end

    it 'should check anniversary calender event is nil' do
      expect(anniversary_feed_nil[:calendar_events]).to be_empty
    end

    it 'should check previous_date in calendar event of anniversary calendar feed' do
      expect(anniversary_feed_previous[:calendar_events][1][:dtstart])
        .to eq((user.start_date - 1.year).strftime('%Y%m%d').to_s)
    end

    it 'should check previous_summary in calendar event of anniversary calendar feed' do
      expect(anniversary_feed_previous[:calendar_events][1][:summary]).not_to be_empty
    end

    it 'should check previous_description in calendar event of anniversary calendar feed' do
      expect(anniversary_feed_previous[:calendar_events][1][:description]).not_to be_empty
    end
  end
end
