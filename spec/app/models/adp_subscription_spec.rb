require 'rails_helper'

RSpec.describe AdpSubscription, type: :model do
  describe 'Associations' do
    it { is_expected.to have_many(:adp_subscription_users).dependent(:destroy) }
  end

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
  end

  describe '#create_subscriptions' do
    context 'should create adp subscriptions' do
      it 'should create adp subscriptions with the given data' do
        adp = AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        expect(adp.class.name).to eq('AdpSubscription')
        expect(AdpSubscription.count).to eq(1)
        expect(AdpSubscription.first.subscriber_first_name).to eq('first_name')
      end

      it 'should create adp subscriptions with nil data' do
        adp = AdpSubscription.create_subscription(nil, 'US')
        expect(adp.class.name).to eq('AdpSubscription')
        expect(AdpSubscription.count).to eq(1)
        expect(AdpSubscription.first.subscriber_first_name).to eq(nil)
      end
    end
  end

  describe '#change_subscription' do
    context 'should change adp subscriptions' do
      it 'should change adp subscriptions with the given data' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'CAN')
        
        @data.body.gsub!(Regexp.union('first_name'), 'updated_first_name')

        adp = AdpSubscription.change_subscription(Hash.from_xml(@data.body), 'US')

        expect(adp).to eq(true)
        expect(AdpSubscription.count).not_to eq(3)
        expect(AdpSubscription.find_by_env('US').subscriber_first_name).to eq('updated_first_name')
      end
    end
  end

  describe '#cancel_subscription' do
    context 'should cancel adp subscriptions' do
      it 'should cancel adp subscriptions with the given data' do
        AdpSubscription.create_subscription(Hash.from_xml(@data.body), 'US')

        adp = AdpSubscription.cancel_subscription(Hash.from_xml(@data.body), 'US')
        expect(adp.class.name).to eq('AdpSubscription')
        expect(AdpSubscription.count).to eq(0)
      end
    end
  end
end