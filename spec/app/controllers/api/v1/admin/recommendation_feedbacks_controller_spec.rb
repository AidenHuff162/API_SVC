require 'rails_helper'

RSpec.describe Api::V1::Admin::RecommendationFeedbacksController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:peter, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
    it 'should return recommendation feedback' do
      post :create, params: { id: user.id, recommendation_user_id: user.id, processType: 'Onboarding', itemType: 0, changeReason: 'changeReason', userSuggestion: 'userSuggestion', itemAction: 0 }, format: :json
      recommendation_feedback = JSON.parse(response.body)
      expect(recommendation_feedback.present?).to eq(true)
      expect(response.status).to eq(201)
    end
  end
end
