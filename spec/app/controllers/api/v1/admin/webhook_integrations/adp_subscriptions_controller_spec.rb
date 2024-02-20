require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::AdpSubscriptionsController, type: :controller do
  before do
     xml_data = '<event>
      <creator>
        <email>email@sad.com</email>
        <firstName>first_name</firstName>
        <lastName>last_name</lastName>
        <uuid>uuid</uuid>
      </creator>
      <payload>
        <company>
          <name>company_name</name>
          <uuid>uuid_company</uuid>
        </company>
        <configuration>
          <entry><value>0</value></entry>
          <entry><value>1</value></entry>
          <entry><value>2</value></entry>
        </configuration>
          <order><item><quantity>2</quantity></item></order>
        </payload>
        <type>event_type</type>
      </event>'
      @data = (double("body", :body => xml_data))
      verifier = ActiveSupport::MessageVerifier.new ENV['ADP_SUBSCRIPTION_SECRET_TOKEN']
      @token = verifier.generate(ENV['ADP_SUBSCRIPTION_SIGNATURE_TOKEN'])
  end

  describe 'get #create_subscription' do
    context 'with signature token' do
      it 'should return ok status and create adp subscription' do
        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @data }
        get :create_subscription, params: { signature_token: @token, env: 'US', url: 'test.com' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscription.count).to eq(1)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not create adp subscription' do
        get :create_subscription, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'get #change_subscription' do
    context 'with signature token' do
      it 'should return ok status and change adp subscription' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        @data.body.gsub!(Regexp.union('first_name'), 'updated_first_name')

        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @data }
        get :change_subscription, params: { signature_token: @token, env: 'US', url: 'test.com' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscription.count).to eq(1)
        expect(AdpSubscription.first.subscriber_first_name).to eq('updated_first_name')
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not change adp subscription' do
        get :change_subscription, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'get #cancel_subscription' do
    context 'with signature token' do
      it 'should return ok status and cancel adp subscription' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')

        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @data }
        get :cancel_subscription, params: { signature_token: @token, env: 'US', url: 'test.com' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscription.count).to eq(0)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not cancel adp subscription' do
        get :cancel_subscription, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'get #notify_subscription' do
    context 'with signature token' do
      it 'should return ok status and notify adp subscription' do
        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @data }
        get :notify_subscription, params: { signature_token: @token, env: 'US', url: 'test.com' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscription.count).to eq(0)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not notify adp subscription' do
        get :notify_subscription, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'get #add_on' do
    context 'with signature token' do
      it 'should return ok status and notify adp subscription' do
        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @data }
        get :add_on, params: { signature_token: @token, env: 'US', url: 'test.com' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscription.count).to eq(0)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not notify adp subscription' do
        get :add_on, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end
end
