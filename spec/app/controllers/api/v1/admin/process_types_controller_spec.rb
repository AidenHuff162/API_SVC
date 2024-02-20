require 'rails_helper'

RSpec.describe Api::V1::Admin::ProcessTypesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it 'should return process types' do
      get :index, format: :json
      process_types = JSON.parse(response.body)
      expect(process_types.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end
end
