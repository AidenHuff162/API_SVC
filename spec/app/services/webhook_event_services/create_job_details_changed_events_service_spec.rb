require 'rails_helper'

RSpec.describe WebhookEventServices::CreateJobDetailsChangedEventsService do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  before(:each) { @job_size = Sidekiq::Queues["webhook_activities"].size }

  describe '#perform' do
    it 'should create webhook event if webhook is present' do
      ::WebhookEventServices::CreateJobDetailsChangedEventsService.new(company, user.attributes, { 'title' => 'test title' }, { field_names: ['Effective Date'], api_field_ids: ['123'], field_types: ['date'], old_values: [3.days.ago], new_values: [2.days.ago]}, 'Role Information', Date.today).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size + 1)
    end

    it 'should not create webhook_events if changed value is not present' do
      ::WebhookEventServices::CreateJobDetailsChangedEventsService.new(company, user.attributes, {}, { field_names: ['Effective Date'], api_field_ids: ['123'], field_types: ['date'], old_values: [3.days.ago], new_values: [2.days.ago]}, 'Role Information', Date.today).perform
      expect(Sidekiq::Queues["webhook_activities"].size).to eq(@job_size)
    end
  end
end 