require 'rails_helper'

RSpec.describe Api::V1::CompaniesController, type: :controller do
  let(:current_company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: current_company) }

  describe "GET #current for signed in user" do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it "simple call should succeed" do
      get :current, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param user_profile_company_serializer" do
      get :current, params: { user_profile_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param user_info_company_serializer" do
      get :current, params: { user_info_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param dashboard_company_serializer" do
      get :current, params: { dashboard_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param preboard_welcome_company_serializer" do
      get :current, params: { preboard_welcome_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param preboard_story_company_serializer" do
      get :current, params: { preboard_story_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param preboard_about_company_serializer" do
      get :current, params: { preboard_about_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param company_landing_company_serializer" do
      get :current, params: { company_landing_company_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param check_jira_integration" do
      get :current, params: { check_jira_integration: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param integration_serializer" do
      get :current, params: { integration_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should succeed with param api_serializer" do
      get :current, params: { api_serializer: true }, format: :json
      expect(response).to have_http_status(:success)
    end

    it "should ensure that current company is equal to signed_in user's company" do
      get :current, format: :json
      json = JSON.parse response.body
      expect(json["id"]).to eq(current_company.id)
    end
  end

  describe "GET #current for unsigned user" do
    it "should return not found" do
      get :current, format: :json
      expect(response).to have_http_status(404)
    end
  end

  describe "GET #auth_current for unsigned user" do
    before do
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it "should return not found" do
      get :auth_current, format: :json
      expect(response).to have_http_status(:success)
    end
  end
end
