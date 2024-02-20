require 'rails_helper'

RSpec.describe Api::V1::RequestInformationsController, type: :controller do

  let(:company) { create(:company, subdomain: 'request_information') }
  let(:sarah) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:nick) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:valid_session) { {} }

  before do
    allow(controller).to receive(:current_user).and_return(nick)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe "GET #show" do
    it 'Should show the data if only requested_to tries to access it' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      result = get :show, params: { id: request_information.id }, as: :json
      expect(JSON.parse(result.body)['id']).to eq(request_information.id)
    end

    it 'Should not show the data if anyone except requested_to tries to access it' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: sarah.id)
      result = get :show, params: { id: request_information.id }, as: :json
      expect(result.message).to eq('Forbidden')
    end

    it 'Should show the data if state is pending' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      result = get :show, params: { id: request_information.id }, as: :json
      expect(JSON.parse(result.body)['id']).to eq(request_information.id)
    end

    it 'Should show get the data if state is other than pending' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      request_information.update(state: RequestInformation.states[:submitted])

      result = get :show, params: { id: request_information.id }, as: :json
      expect(result.message).to eq('Forbidden')
    end
  end

  describe "PUT #update" do
    it 'Should update the data if only requested_to tries to update it' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      result = put :update, params: { id: request_information.id, state: RequestInformation.states[:submitted] }, as: :json

      expect(result.status).to eq(204)
    end

    it 'Should not update the data if anyone except requested_to tries to update it' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: nick.id, requested_to_id: sarah.id)
      result = put :update, params: { id: request_information.id, state: RequestInformation.states[:submitted] }, as: :json

      expect(result.message).to eq('Forbidden')
    end

    it 'Should update the data if state is pending' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      result = put :update, params: { id: request_information.id, state: RequestInformation.states[:submitted] }, as: :json
      expect(result.status).to eq(204)
    end

    it 'Should update the data if state is other than pending' do
      request_information = FactoryGirl.create(:request_information, company: company, requester_id: sarah.id, requested_to_id: nick.id)
      request_information.update(state: RequestInformation.states[:submitted])

      result = put :update, params: { id: request_information.id, state: RequestInformation.states[:submitted] }, as: :json
      expect(result.message).to eq('Forbidden')
    end
  end
end
