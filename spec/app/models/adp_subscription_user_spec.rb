require 'rails_helper'

RSpec.describe AdpSubscriptionUser, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:adp_subscription) }
  end

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
      @user_unassign_data = (double("body", :body => user_unassign_xml_data))
      @user_data = (double("body", :body => user_xml_data))
  end

  describe '#find_adp_subscription' do
    context 'should find adp subscriptions' do
      it 'should find adp subscriptions with the given organization_oid' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'CAN')

        adp_us = AdpSubscriptionUser.find_adp_subscription("0", 'US')
        adp_can = AdpSubscriptionUser.find_adp_subscription("0", 'CAN')

        expect(adp_us.class.name).to eq('AdpSubscription')
        expect(adp_can.class.name).to eq('AdpSubscription')
      end

      it 'should not find adp subscriptions if the organization_oid is not present' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        adp = AdpSubscriptionUser.find_adp_subscription(nil, 'US')

        expect(adp.class.name).not_to eq('AdpSubscription')
      end

      it 'should not find adp subscriptions if present but of other env' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        adp = AdpSubscriptionUser.find_adp_subscription("0", 'CAN')

        expect(adp.class.name).not_to eq('AdpSubscription')
      end
    end
  end

  describe '#assign_user' do
    context 'should assign adp subscription users' do
      it 'should assign user to adp subscriptions with the given data' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        adp = AdpSubscriptionUser.assign_user(Hash.from_xml(@user_data.body), 'US')
        expect(adp.class.name).to eq('AdpSubscriptionUser')
        expect(AdpSubscriptionUser.count).to eq(1)
        expect(AdpSubscriptionUser.first.first_name).to eq('first_name')
      end
    end
  end

  describe '#unassign_user' do
    context 'should unassign users adp subscriptions' do
      it 'should unassign user adp subscriptions with the given data' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        AdpSubscriptionUser.assign_user(Hash.from_xml(@user_data.body), 'US')

        adp = AdpSubscriptionUser.unassign_user(Hash.from_xml(@user_unassign_data.body), 'US')
        expect(adp.class.name).to eq('AdpSubscriptionUser')
        expect(AdpSubscriptionUser.count).to eq(0)
      end
    end
  end
end