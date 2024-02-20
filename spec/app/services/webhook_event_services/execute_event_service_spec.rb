require 'rails_helper'

RSpec.describe WebhookEventServices::ExecuteEventService do
  let(:company) { create(:company) }
  let(:webhook_event) { create(:webhook_event, status: :pending, company: company) }

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#perform' do
    it 'should not dispatch webhook event if company is not present' do
      ::WebhookEventServices::ExecuteEventService.new(nil, webhook_event.id).perform
      expect(webhook_event.status).to eq ('pending')
    end

    it 'should not dispatch webhook event if event is not present' do
      ::WebhookEventServices::ExecuteEventService.new(company.id, nil).perform
      expect(webhook_event.status).to eq ('pending')
    end

    it 'should dispatch webhook if webhook and signature is valid' do
      stub_request(:post, 'http://company.domain/api/v1/admin/webhooks').
        with(
          body: "{\"request\":\"data\",\"webhook_event\":{\"id\":\"test\"}}",
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Faraday v0.17.6'
          }).to_return(status: 200, body: "", headers: {})
      ::WebhookEventServices::ExecuteEventService.new(company.id, webhook_event.id).perform
      expect(webhook_event.reload.status).to eq ('succeed')
    end

    it 'should not dispatch webhook if signature is not valid' do
      stub_request(:post, "http://company.domain/api/v1/admin/webhooks").
        with(
          body: "{\"request\":\"data\",\"webhook_event\":{\"id\":\"test\"}}",
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Faraday v0.17.1'
          }).to_return(status: 401, body: "", headers: {})
      ::WebhookEventServices::ExecuteEventService.new(company.id, webhook_event.id).perform
      expect(webhook_event.reload.status).to eq ('failed')
    end
  end
end 