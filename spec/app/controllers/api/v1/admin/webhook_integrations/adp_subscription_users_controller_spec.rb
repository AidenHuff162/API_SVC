require 'rails_helper'

RSpec.describe Api::V1::Admin::WebhookIntegrations::AdpSubscriptionUsersController, type: :controller do
  before do
    user_xml_data = '<event>
      <payload>
        <configuration>
          <entry><value>0</value></entry>
          <entry><value>1</value></entry>
        </configuration>
        <user>
          <attributes>
            <entry><value>zip_code</value></entry>
            <entry><value>bill_rate</value></entry>
            <entry><value>password</value></entry>
            <entry><value>true</value></entry>
            <entry><value>time_zone</value></entry>
            <entry><value>access_right</value></entry>
            <entry><value>user_name</value></entry>
            <entry><value>title</value></entry>
            <entry><value>department</value></entry>
            <entry><value>identification_number</value></entry>
          </attributes>
          <email>asdf@asd.com</email>
          <firstName>first_name</firstName>
          <lastName>last_name</lastName>
          <uuid>uuid</uuid>
        </user>
      </payload>
    </event>'

    user_unassign_xml_data = '<event>
      <payload>
        <configuration>
          <entry><value>0</value></entry>
          <entry><value>1</value></entry>
        </configuration>
        <user>
          <uuid>uuid</uuid>
          </user>
      </payload>
    </event>'

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
      @user_data = (double("body", :body => user_xml_data))
      @user_unassign_data = (double("body", :body => user_unassign_xml_data))
      verifier = ActiveSupport::MessageVerifier.new ENV['ADP_SUBSCRIPTION_SECRET_TOKEN']
      @token = verifier.generate(ENV['ADP_SUBSCRIPTION_SIGNATURE_TOKEN'])
  end

  describe 'get #assign_users' do
    context 'with signature token' do
      it 'should return ok status and assign users' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @user_data }
        get :assign_users, params: { signature_token: @token, env: 'US' }, as: :json
        expect(response.status).to eq(200)
        expect(AdpSubscriptionUser.count).to eq(1)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not assign users' do
        get :assign_users, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'get #unassign_users' do
    context 'with signature token' do
      it 'should return ok status and usassign user' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        AdpSubscriptionUser.assign_user(Hash.from_xml(@user_data.body), 'US')

        expect_any_instance_of(OAuth::AccessToken).to receive(:get) { @user_unassign_data }
        get :unassign_users, params: { signature_token: @token, env: 'US' }, format: :json
        expect(response.status).to eq(200)
        expect(AdpSubscriptionUser.count).to eq(0)
      end
    end

    context 'without signature token' do
      it 'should return unauthorized status and not unassign user' do
        get :unassign_users, params: { signature_token: nil }, format: :json
        expect(response.status).to eq(401)
      end
    end
  end

end
