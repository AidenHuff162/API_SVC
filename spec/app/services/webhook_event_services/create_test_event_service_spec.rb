require 'rails_helper'

RSpec.describe WebhookEventServices::CreateTestEventService do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:webhook) { create(:webhook, webhook_key: :test, company: company) }

  describe '#perform' do
    it 'should not create webhook event if webhook is not present' do
      ::WebhookEventServices::CreateTestEventService.new(company, nil, nil).perform
      expect(webhook.webhook_events.count).to eq (0)
    end

    it 'should create webhook_events if webhook is present' do
      ::WebhookEventServices::CreateTestEventService.new(company, webhook, user).perform
      expect(webhook.webhook_events.count).to eq (1)
    end
  end
end 