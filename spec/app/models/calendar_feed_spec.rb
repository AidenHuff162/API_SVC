require 'rails_helper'

RSpec.describe CalendarFeed, type: :model do
  let(:company){ create(:company) }
  let(:user) { create(:user, company: company) }
  
  describe 'validations' do
    subject(:calendar_feed){ build(:calendar_feed, company: company, user: user) }
    it { should validate_uniqueness_of(:feed_type).ignoring_case_sensitivity.scoped_to(:user_id) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:company) }
  end

  describe 'callbacks' do
    context 'initialize_calendar_feeds_param' do
      before do
        @calendar_feed = create(:calendar_feed, company: company, user: user)
      end
      it 'should have feed id' do
        expect(@calendar_feed.feed_id).not_to eq(nil)
      end
      it 'should have feed url' do
        expect(@calendar_feed.feed_url).not_to eq(nil)
      end
    end
  end
end
