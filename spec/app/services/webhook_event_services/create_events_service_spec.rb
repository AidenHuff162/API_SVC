require 'rails_helper'

RSpec.describe WebhookEventServices::CreateEventsService do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:webhook) { create(:webhook, webhook_key: :test, configurable: { stages: ['all'] }, company: company) }

  describe '#perform' do
    it 'should not create webhook event if webhook is not present' do
      ::WebhookEventServices::CreateEventsService.new(company, {type: nil}).perform
      expect(webhook.webhook_events.count).to eq (0)
    end

    it 'should create webhook_events if webhook is present' do
      webhook.reload
      ::WebhookEventServices::CreateEventsService.new(company, {type: 'stage_completed', triggered_for: user.id, stage: :preboarding}).perform
      expect(webhook.webhook_events.count).to eq (1)
    end
  end
end 