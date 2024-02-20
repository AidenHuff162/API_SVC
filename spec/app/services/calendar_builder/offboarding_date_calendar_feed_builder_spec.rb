require 'rails_helper'

RSpec.describe CalendarBuilder::OffboardingDateCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:offboarding_user, company: company, last_day_worked: Time.zone.today) }
  let(:user_nil) { create(:user, company: company) }
  let(:calendar_feed) { create(:offboarding_calendar_feed, user: user, company: company) }
  let(:calendar_feed_nil) { create(:offboarding_calendar_feed, user: user_nil, company: company) }

  context 'with offboarding feed calendar spec' do
    let(:offboarding_feed) { described_class.new(calendar_feed).call }
    let(:offboarding_feed_nil) { described_class.new(calendar_feed_nil).call }

    it 'should check offboarding feed calendar name' do
      expect(offboarding_feed[:calendar_name]).to eq("Offboarding Calendar for #{company.name}")
    end

    it 'should check start_date in calendar event of offboarding calendar feed' do
      expect(offboarding_feed[:calendar_events][0][:dtstart]).to eq(user.termination_date)
    end

    it 'should check summary in calendar event of offboarding calendar feed' do
      expect(offboarding_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check description in calendar event of offboarding calendar feed' do
      expect(offboarding_feed[:calendar_events][0][:description]).not_to be_empty
    end

    it 'should check offboarding calender event is nil' do
      expect(offboarding_feed_nil[:calendar_events]).to be_empty
    end
  end
end
