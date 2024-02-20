require 'rails_helper'

RSpec.describe WebhookEventServices::CreateProfileChangedEventsService do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  before(:each) { @job_size = Sidekiq::Queues["webhook_activities"].size }

  describe '#perform' do
    it 'should create webhook event if webhook is present' do
      ::WebhookEventServices::CreateProfileChangedEventsService.new(company, user.attributes, {'github' => 'test title'}).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size + 1)
    end

    it 'should not create webhook_events if changed value is not present' do
      ::WebhookEventServices::CreateProfileChangedEventsService.new(company, user.attributes, {}).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size)
    end
  end
end 