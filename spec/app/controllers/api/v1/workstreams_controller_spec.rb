require 'rails_helper'

RSpec.describe Api::V1::WorkstreamsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #basic_index" do
    context 'should return workstreams' do
      it 'should return basic workstreams' do
        get :basic_index, format: :json
        workstreams = JSON.parse(response.body)
        
        expect(workstreams.present?).to eq(true)
        expect(response.status).to eq(200)
      end

      it 'should return workspace workstreams' do
        get :workspace_index, format: :json
        workstreams = JSON.parse(response.body)
        
        expect(workstreams.present?).to eq(true)
        expect(response.status).to eq(200)
      end

      it 'should return custom workstreams' do
        get :get_custom_workstream, format: :json
        workstreams = JSON.parse(response.body)
        
        expect(workstreams.present?).to eq(true)
        expect(response.status).to eq(200)
      end

      it 'should return all workstreams' do
        get :index, format: :json
        workstreams = JSON.parse(response.body)
        
        expect(workstreams.present?).to eq(true)
        expect(response.status).to eq(200)
      end
    end
  end
end
