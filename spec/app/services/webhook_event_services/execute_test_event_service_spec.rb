require 'rails_helper'

RSpec.describe WebhookEventServices::ExecuteTestEventService do
  let(:company) { create(:company) }

  before(:all) do
    @params = { target_url: 'http://company.domain/api/v1/admin/webhooks' }
    WebMock.disable_net_connect!
  end

  describe '#perform' do
    it 'should not dispatch webhook event if company webhook token is not present' do
      company.webhook_token = nil
      response = ::WebhookEventServices::ExecuteTestEventService.new(@params, company).perform
      expect(response).to eq (nil)
    end

    it 'should not dispatch webhook event if event is not present' do
      response = ::WebhookEventServices::ExecuteTestEventService.new(nil, company).perform
      expect(response).to eq (nil)
    end

    it 'should dispatch webhook and return data if webhook and signature is valid' do
      stub_request(:post, 'http://company.domain/api/v1/admin/webhooks').
        with(
          body: "{\"data\":\"testing webhook endpoint while creation\",\"test_request\":true}",
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Faraday v0.17.6',
          }
        ).to_return(status: 200, body: "", headers: {})
      response = ::WebhookEventServices::ExecuteTestEventService.new(@params, company).perform
      
      expect(response.keys).to eq ([:created_at, :event_id, :status, :response_body])
      expect(response[:status]).to eq ('Success')
    end

    it 'should not dispatch webhook if signature is not valid' do
      stub_request(:post, 'http://company.domain/api/v1/admin/webhooks').
        with(
          body: "{\"data\":\"testing webhook endpoint while creation\",\"test_request\":true}",
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Content-Type'=>'application/json',
          'User-Agent'=>'Faraday v0.17.6'
          }).to_return(status: 400, body: "", headers: {})
      response = ::WebhookEventServices::ExecuteTestEventService.new(@params, company).perform
      
      expect(response.keys).to eq ([:created_at, :event_id, :status, :response_body])
      expect(response[:status]).to eq ('Failed')
    end
  end
end 