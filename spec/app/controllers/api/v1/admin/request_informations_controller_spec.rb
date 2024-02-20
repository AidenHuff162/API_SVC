require 'rails_helper'

RSpec.describe Api::V1::Admin::RequestInformationsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:employee) { create(:user, role: :employee, company: company) }
  let(:valid_session) { {} }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe "POST #create" do
    it 'Should not create request information if profile field ids are nil' do
      post :create, params: { profile_field_ids: [] }, format: :json
      expect(response.message).to eq('Unprocessable Entity')
    end

    it 'Should create request information if profile field ids are present' do
      post :create, params: { profile_field_ids: ['fn', 'ln'], requested_to_id: user.id }, format: :json
      expect(response.status).to eq(204)
      expect(company.request_informations.count).not_to eq(0)
    end

    it 'Should update state from requested to pending after creation' do
      post :create, params: { profile_field_ids: ['fn', 'ln'], requested_to_id: user.id }, format: :json
      expect(company.request_informations.take.state).to eq('pending')
    end
  end

  describe "POST #bulk_request" do
    it 'Should not create request information if profile field ids are nil' do
      Sidekiq::Testing.inline! do
        post :bulk_request, params: { profile_field_ids: [], user_ids: [user.id, user1.id] }, format: :json
        expect(company.request_informations.count).to eq(0)
      end
    end

    it 'Should not create request information if current_user is not account owner' do
      Sidekiq::Testing.inline! do
        allow(controller).to receive(:current_user).and_return(employee)
        post :bulk_request, params: { profile_field_ids: [], user_ids: [user.id, user1.id] }, format: :json
        expect(response.status).to eq(403)
      end
    end

    it 'Should create bulk request information if profile field ids are present' do
      Sidekiq::Testing.inline! do
        post :bulk_request, params: { profile_field_ids: ['fn', 'ln'], user_ids: [user.id, user1.id] }, format: :json
        expect(response.status).to eq(204)
        expect(company.request_informations.count).not_to eq(0)
      end
    end

    it 'Should update state from requested to pending after creation' do
      Sidekiq::Testing.inline! do
        post :bulk_request, params: { profile_field_ids: ['fn', 'ln'], user_ids: [user.id, user1.id] }, format: :json
        expect(company.request_informations.take.state).to eq('pending')
      end
    end
  end
end
