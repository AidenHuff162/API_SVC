require 'rails_helper'

RSpec.describe WebhookServices::ZapierService do
  let(:company) { create(:company) }
  let(:webhook) { create(:webhook, webhook_key: :test, company: company) }

  describe '#subscribe' do
    it 'should return 404 if domain is not of current company' do
      result = ::WebhookServices::ZapierService.new({company_domain: 'rocketship.test.com'}, company).subscribe
      expect(result[:code]).to eq (404)
    end

    it 'should return 404 if webhook key invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: nil }, company).subscribe
      expect(result[:code]).to eq (404)
    end

    it 'should return 204 and update target url if webhook key valid' do
      target_url = 'http://company.domain/api/v1/admin/webhooks'
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: webhook.webhook_key, target_url: target_url }, company).subscribe
      expect(result[:code]).to eq (204)
      expect(webhook.reload.target_url).to eq (target_url)
    end
  end

  describe '#unsubscribe' do
    it 'should return 404 if webhook key invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: nil }, company).unsubscribe
      expect(result[:code]).to eq(404)
    end

    it 'should return 204 and update state to inactive if webhook key valid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: webhook.webhook_key }, company).unsubscribe
      expect(result[:code]).to eq (204)
      expect(webhook.reload.state).to eq('inactive')
    end
  end

  describe '#authenticate' do
    it 'should return false if webhook key invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: nil }, company).authenticate
      expect(result).to eq(false)
    end

    it 'should return false if domain is invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: 'rocketship.test.com', key: webhook.webhook_key }, company).authenticate
      expect(result).to eq(false)
    end

    it 'should return 204 and update state to inactive if webhook key valid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: webhook.webhook_key }, company).authenticate
      expect(result).to eq (true)
    end
  end

  describe '#perform_list_zap' do
    it 'should return empty body if webhook key invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: nil }, company).perform_list_zap
      expect(result).to eq({})
    end

    it 'should return empty body if domain is invalid' do
      result = ::WebhookServices::ZapierService.new({company_domain: 'rocketship.test.com', webhook_key: webhook.webhook_key }, company).perform_list_zap
      expect(result).to eq({})
    end

    it 'should return true if webhook key valid and company is valid' do
      allow_any_instance_of(WebhookEventServices::TestParamsBuilderService).to receive(:prepare_test_event_params).and_return(true)
      result = ::WebhookServices::ZapierService.new({company_domain: company.domain, key: webhook.webhook_key }, company).perform_list_zap
      expect(result).to eq (true)
    end
  end
end 