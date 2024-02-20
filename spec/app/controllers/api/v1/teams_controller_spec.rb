require 'rails_helper'

RSpec.describe Api::V1::TeamsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:company2) { create(:company, subdomain: "foo2") }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it "should return all the teams for current company" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      get :index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team5 = create(:team, company: company2)

      get :index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe even if company_id is not provided" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team4 = create(:team, company: company2)
      get :index, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end
  end

  describe "GET #basic_index" do
    it "should return all the teams for current company" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      get :basic_index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team4 = create(:team, company: company2)

      get :basic_index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe even if company_id is not provided" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team4 = create(:team, company: company2)
      get :basic_index, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end
  end

  describe "GET #report_index" do
    it "should return all the teams for current company" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      get :report_index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team4 = create(:team, company: company2)

      get :report_index, params: { company_id: company.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end

    it "should return the teams that are tenant safe even if company_id is not provided" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      team3 = create(:team, company: company2)
      team4 = create(:team, company: company2)
      get :report_index, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json.count).to be(2)
    end
  end

  describe "GET #show" do
    it "should return the team with id provided" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      get :show, params: { id: team1.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json["id"]).to be(team1.id)
    end
  end

  describe "GET #basic" do
    it "should return the team with id provided" do
      team1 = create(:team, company: company)
      team2 = create(:team, company: company)
      get :basic, params: { id: team1.id }, format: :json

      json = JSON.parse(response.body)
      expect(response).to have_http_status(200)
      expect(json["id"]).to be(team1.id)
    end
  end


  describe 'Get #people_page_index' do
    let(:user1) { create(:peter, company: company) }

    before do
      allow(controller).to receive(:current_user).and_return(user1)
      allow(controller).to receive(:current_company).and_return(company)
    end

    context 'Admin' do
      it 'should be able to get people page index' do
        get :people_page_index, format: :json
        expect(response).to have_http_status(200)
      end

      it 'should not be able tso get people page index with no access permission' do
        user1.user_role.permissions["platform_visibility"]["people"] = "no_access"
        user1.save!
        get :people_page_index, format: :json
        expect(response).to have_http_status(403)
      end
    end
  end
end
