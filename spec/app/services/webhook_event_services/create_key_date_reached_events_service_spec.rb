require 'rails_helper'

RSpec.describe WebhookEventServices::CreateKeyDateReachedEventsService do
  let(:company) { create(:company) }
  
  before(:each) { @job_size = Sidekiq::Queues["webhook_activities"].size }

  describe '#perform' do
    it 'should create webhook event if webhook is present' do
      user = create(:user, start_date: company.time.to_date, company: company) 
      ::WebhookEventServices::CreateKeyDateReachedEventsService.new(company).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size + 1)
    end

    it 'should not create webhook_events if changed value is not present' do
      user = create(:user, start_date: 2.days.ago, company: company) 
      ::WebhookEventServices::CreateKeyDateReachedEventsService.new(company).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size)
    end
  end
end 