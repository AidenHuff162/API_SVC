require 'rails_helper'

RSpec.describe CalendarBuilder::OverDueActivitiesCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:offboarding_user, company: company) }
  let(:user_nil) { create(:user, company: company) }
  let(:calendar_feed) { create(:over_due_activities_feed, user: user, company: company) }
  let(:calendar_feed_nil) { create(:over_due_activities_feed, user: user_nil, company: company) }
  let(:task) { create(:task, user: user) }
  let!(:task_user_connection) { create(:task_user_connection, user: user) }

  context 'with over due activities feed calendar spec' do
    let(:over_due_feed) { described_class.new(calendar_feed).call }
    let(:over_due_feed_nil) { described_class.new(calendar_feed_nil).call }

    it 'should check over due activities feed calendar name' do
      expect(over_due_feed[:calendar_name]).to eq(I18n.t('calendar_feed.over_due_activity_feed.calendar_name'))
    end

    it 'should check due_date in calendar event of over due activities calendar feed' do
      expect(over_due_feed[:calendar_events][0][:dtstart]).to eq(task_user_connection.due_date)
    end

    it 'should check summary in calendar event of over due activities calendar feed' do
      expect(over_due_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check description in calendar event of over due activities calendar feed' do
      expect(over_due_feed[:calendar_events][0][:description]).not_to be_empty
    end

    it 'should check over due activities calender event is nil' do
      expect(over_due_feed_nil[:calendar_events]).to be_empty
    end
  end
end
