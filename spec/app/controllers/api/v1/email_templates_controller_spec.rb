require 'rails_helper'

RSpec.describe Api::V1::EmailTemplatesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "Get Index" do
    it "gets email templates from index" do
      team = Team.create
      returned_req = get :index, params: { company_id: 1, user_id: user.id }, format: :json
      res_code = returned_req.response_code
      expect(res_code).to eq 200
    end

    it "gets email templates from index" do
      team = Team.create
      returned_req = get :index, params: { company_id: 1, user_id: user.id, email_type: 'offboarding' }, format: :json
      res_code = returned_req.response_code
      expect(res_code).to eq 200
    end
  end
end
