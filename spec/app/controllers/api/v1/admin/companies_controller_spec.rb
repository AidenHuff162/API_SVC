require 'rails_helper'

RSpec.describe Api::V1::Admin::CompaniesController, type: :controller do
  let(:current_company) { create(:company) }
  let(:company_with_milestone) { create(:company, subdomain: 'foofii', milestones: [FactoryGirl.create(:milestone)]) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: current_company) }

  describe "POST #update" do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it "should update calendar_permissions" do
      calendar_permissions = current_company.calendar_permissions
      calendar_permissions = {"anniversary" => false, "birthday" => true}

      post :update, params: { id: current_company.id, calendar_permissions: calendar_permissions }, as: :json
      expect(response).to have_http_status(:success)
      json = JSON.parse response.body
      expect(json["calendar_permissions"]["anniversary"]).to eq(false)
      expect(json["calendar_permissions"]["birthday"]).to eq(true)
    end
  end

  describe 'milestone checks' do
    before do
      allow(controller).to receive(:current_user).and_return(user)
      allow(controller).to receive(:current_company).and_return(user.company)
    end

    it 'should return a new company' do
      get :current, format: :json
      expect(response).to have_http_status(:success)
    end

    it 'should create a new company and add milestone' do
      faker_milestone = FactoryGirl.create(:milestone)
      milestone = { name: faker_milestone[:name], description: faker_milestone[:description], happened_at: faker_milestone[:happened_at]}
      milestones = []
      milestones.push milestone
      post :update, params: {id: current_company.id, milestones: milestones}, as: :json
      expect(response.status).to eq(201)
    end

    it 'should update a milestone to existing company' do
      faker_milestone = FactoryGirl.create(:milestone)
      milestone = { name: faker_milestone[:name], description: faker_milestone[:description], happened_at: faker_milestone[:happened_at]}
      milestones = []
      milestones.push milestone
      post :update, params: {id: company_with_milestone.id, milestones: milestones}, as: :json
      result = JSON.parse(response.body)

      expect(milestones.first[:name]).to eq(result['milestones'].first['name'])
      expect(milestones.first[:description]).to eq(result['milestones'].first['description'])
      expect(response.status).to eq(201)
    end

    it 'should delete a milestone to existing company' do
      faker_milestone = FactoryGirl.create(:milestone, company: current_company)
      expect(current_company.milestones.count).to eq(1)
      faker_milestone.destroy!
      expect(current_company.milestones.count).to eq(0)
    end

    it 'should not update an already existing milestone without a name' do
      faker_milestone = FactoryGirl.create(:milestone, company: current_company)
      post :update, params: {id: faker_milestone.id, name: ''}, as: :json
      result = JSON.parse(response.body)
      expect(result['errors'].first['messages'].first).to eq("Name can't be blank")
    end
  end
end
