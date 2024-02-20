require 'rails_helper'

RSpec.describe Api::V1::Webhook::JazzController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let!(:integration) { create(:jazz_integration, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow_any_instance_of(AtsIntegrationsService::JazzHr).to receive(:verify_integration_credentials?) {true}
  end

  describe 'POST #create' do
    it "should return 401 status" do
      request.headers["HTTP_X_JAZZHR_EVENT"] = "CANDIDATE-EXPORT"
      post :create, format: :json
      expect(response.status).to eq(201)
    end

    it "should return 401 status" do
      request.headers["HTTP_X_JAZZHR_EVENT"] = "VERIFY"
      post :create, format: :json
      expect(response.status).to eq(200)
    end
  end
end