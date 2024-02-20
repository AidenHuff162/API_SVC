require 'rails_helper'

RSpec.describe RequestInformation, type: :model do
  describe 'Associations' do
    it { is_expected.to belong_to(:company) }
  end

  subject(:company) { FactoryGirl.create(:company, subdomain: 'request-information') }
  subject(:nick) { FactoryGirl.create(:user, company: company) }

  describe 'Validation' do
    it 'Should not create request information if profile field ids are nil' do
      expect{FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: nick.id, profile_field_ids: [])}.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'Should create request information if profile field ids are not nil' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: nick.id, profile_field_ids: ['fn'])
      expect(request_information.id).not_to eq(nil)
    end
  end

  describe 'After Create' do
    it 'Should successfully change state from requested to pending after sending an email' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: nick.id, profile_field_ids: ['fn'])
      expect(request_information.state).to eq('pending')
    end
  end

  describe 'After Update' do
    it 'Should successfully change state from pending to submitted after sending an email' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: nick.id, profile_field_ids: ['fn'])
      request_information.update(state: RequestInformation.states[:submitted])

      expect(request_information.state).to eq('submitted')
    end
  end
end
