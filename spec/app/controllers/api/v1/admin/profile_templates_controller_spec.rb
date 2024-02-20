require 'rails_helper'

RSpec.describe Api::V1::Admin::ProfileTemplatesController, type: :controller do

  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it 'should return profile templates' do
      get :index, params: { bulk_onboarding: true }, format: :json
      JSON.parse(response.body)
      expect(response.status).to eq(200)
    end

    it 'should return profile templates' do
      get :index,  params: { profile_page: true }, format: :json
      JSON.parse(response.body)
      expect(response.status).to eq(200)
    end

    it 'should return profile templates' do
      get :index,  params: { process_type: true }, format: :json
      JSON.parse(response.body)
      expect(response.status).to eq(200)
    end

    it 'should return profile templates' do
      get :index, format: :json
      JSON.parse(response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "POST #create" do
    let!(:process_type) { create(:process_type, company_id: company.id) }
    it 'should create profile templates' do
      post :create, params: { name: 'name', process_type_id: process_type.id }, format: :json
      template = JSON.parse(response.body)
      expect(template.present?).to eq(true)
      expect(response.status).to eq(201)
    end
  end

  describe "GET #show" do
    let!(:process_type) { create(:process_type, company_id: company.id) }
    let!(:profile_template) { create(:profile_template, company: company, edited_by: user, process_type: process_type, name: "Onboarding Profile Template") }
    it 'should return profile template' do
      get :show, params: { id: profile_template.id }, format: :json
      template = JSON.parse(response.body)
      expect(template.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT #update" do
    let!(:process_type) { create(:process_type, company_id: company.id) }
    let!(:profile_template) { create(:profile_template, company: company, edited_by: user, process_type: process_type, name: "Onboarding Profile Template") }
    let!(:custom_field) { create(:custom_field, company: company) }
    let!(:custom_table) { create(:custom_table, company: company) }
    it 'should update and return profile template' do
      ctc = ProfileTemplateCustomTableConnection.create!(profile_template_id: profile_template.id, custom_table_id: custom_table.id, position: 0)
      cfc = ProfileTemplateCustomFieldConnection.create!(profile_template_id: profile_template.id, custom_field_id: custom_field.id, required: true, position: 0)
      put :update, params: { id: profile_template.id, profile_template_custom_table_connections_attributes: [ctc.attributes], profile_template_custom_field_connections_attributes: [[]] }, format: :json
      template = JSON.parse(response.body)
      expect(template.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end

  describe "DELETE #destroy" do
    let!(:process_type) { create(:process_type, company_id: company.id) }
    let!(:profile_template) { create(:profile_template, company: company, edited_by: user, process_type: process_type, name: "Onboarding Profile Template") }

    it 'should delete profile template' do
      delete :destroy, params: { id: profile_template.id }, format: :json
      expect(response.status).to eq(204)
    end
  end

  describe "POST #duplicate" do
    let!(:process_type) { create(:process_type, company_id: company.id) }
    let!(:profile_template) { create(:profile_template, company: company, edited_by: user, process_type: process_type, name: "Onboarding Profile Template") }

    it 'should duplicate profile template' do
      post :duplicate, params: { id: profile_template.id }, format: :json
      template = JSON.parse(response.body)
      expect(template.present?).to eq(true)
      expect(response.status).to eq(201)
    end
  end
end
