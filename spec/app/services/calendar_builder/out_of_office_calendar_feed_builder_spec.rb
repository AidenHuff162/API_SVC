require 'rails_helper'

RSpec.describe CalendarBuilder::OutOfOfficeCalendarFeedBuilder do
  let(:company) { create(:company) }
  let(:user) { create(:user_with_manager_and_policy,:auto_approval, company: company, start_date: Time.zone.today - 1.year) }
  let(:calendar_feed) { create(:out_of_office_calendar_feed, user: user, company: company) }
  let!(:pto_policy) { create(:default_pto_policy) }


  context 'with out of office feed calendar spec' do
    let(:out_of_office_feed) { described_class.new(calendar_feed).call }

    it 'should check out of office feed calendar name' do
      expect(out_of_office_feed[:calendar_name]).to eq("Out Of Office Calendar for #{company.name}")
    end

    it 'should check pto request event start date' do
      User.current = user
      pto = FactoryGirl.create(:default_pto_request, :approved_pto_request, user: user, pto_policy: pto_policy)
      expect(out_of_office_feed[:calendar_events][0][:dtstart]).to eq(pto.begin_date)
    end

    it 'should check pto request event end date' do
      User.current = user
      pto = FactoryGirl.create(:default_pto_request, :approved_pto_request, user: user, pto_policy: pto_policy)
      expect(out_of_office_feed[:calendar_events][0][:dtend]).to eq(pto.end_date)
    end

    it 'should check pto request event summary' do
      User.current = user
      pto = FactoryGirl.create(:default_pto_request, :approved_pto_request, user: user, pto_policy: pto_policy)
      expect(out_of_office_feed[:calendar_events][0][:summary]).not_to be_empty
    end

    it 'should check pto request event description' do
      User.current = user
      pto = FactoryGirl.create(:default_pto_request, :approved_pto_request, user: user, pto_policy: pto_policy)
      expect(out_of_office_feed[:calendar_events][0][:description]).not_to be_empty
    end
  end
end
