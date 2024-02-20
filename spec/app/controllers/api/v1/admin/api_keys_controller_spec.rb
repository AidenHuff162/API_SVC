require 'rails_helper'

RSpec.describe Api::V1::Admin::ApiKeysController, type: :controller do

  let(:user) { create(:user) }
  generated_key = nil

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #generate_api_key" do
    it "should generate api key against company sucessfully" do
      get :generate_api_key, format: :json
      generated_key = JSON.parse(response.body)["key"]
      expect(response.status).to eq(200)
      expect(generated_key).not_to be_nil
    end
  end

  describe "Api - key - module" do
    it "should create api key against the company" do
      post :create, params: { name: 'sample key', key: generated_key }, format: :json

      response_key = ApiKey.find(JSON.parse(response.body)["id"]).key
      expect(response.status).to eq(201)
      expect(response.message).to eq("Created")
      expect(SCrypt::Password.new(response_key)).to eq(generated_key)
    end

    it "should get all the api keys against the company" do
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)

      get :index, format: :json

      expect(response.status).to eq(200)
      created_keys = JSON.parse(response.body)
      expect(created_keys.length).to be(2)
    end

    it "should delete the api key with id against the company" do
      created_key = FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)

      delete :destroy, params: { id: created_key.id }, format: :json
      expect(response.status).to eq(204)
    end

    it "should not create api key without name and key" do
      post :create, format: :json

      expect(response.status).to eq(422)
      json = JSON.parse(response.body)
      expect(json["errors"][0]["details"]).to eq("Validation failed")
      expect(json["errors"][0]["messages"]).to include("Name can't be blank")
      expect(json["errors"][0]["messages"]).to include("Encrypted key can't be blank")
    end

    it "should not create api key without key" do
      post :create, params: { name: "sample" }, format: :json

      expect(response.status).to eq(422)
      json = JSON.parse(response.body)
      expect(json["errors"][0]["details"]).to eq("Validation failed")
      expect(json["errors"][0]["messages"]).to include("Encrypted key can't be blank")
    end

    it "should not create api key without name" do
      post :create, params: { key: generated_key }, format: :json

      expect(response.status).to eq(422)
      json = JSON.parse(response.body)
      expect(json["errors"][0]["details"]).to eq("Validation failed")
      expect(json["errors"][0]["messages"]).to include("Name can't be blank")
    end
  end

  describe "API keys with admin role" do
    let(:peter) { create(:peter, company: user.company) }
    let(:user2) { create(:user) }
    before do
      allow(controller).to receive(:current_user).and_return(peter)
      allow(controller).to receive(:current_company).and_return(peter.company)
    end

    it "should not allow to generate new key" do
      post :create, params: { name: 'sample key', key: generated_key }, format: :json
      error = JSON.parse(response.body)["errors"][0]
      expect(response.status).to eq(403)
      expect(response.message).to eq("Forbidden")
      expect(error["details"]).to eq("You are not authorized to access this page.")
    end

    it "should allow to delete it" do
      created_key = FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)
      delete :destroy, params: { id: created_key.id }, format: :json
      expect(response.status).to eq(204)
    end

    it "should not allow to delete api key against other company" do
      created_key = FactoryGirl.create(:api_key, edited_by_id: user2.id, company_id: user2.company.id)
      delete :destroy, params: { id: created_key.id }, format: :json
      error = JSON.parse(response.body)["errors"][0]
      expect(response.status).to eq(403)
      expect(response.message).to eq("Forbidden")
      expect(error["details"]).to eq("You are not authorized to access this page.")
    end

    it "should get all the api keys against the company" do
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)

      get :index, format: :json

      expect(response.status).to eq(200)
      created_keys = JSON.parse(response.body)
      expect(created_keys.length).to be(2)
    end
  end

  describe "API keys with employee role" do
    let(:tim) { create(:tim, company: user.company) }
    before do
      allow(controller).to receive(:current_user).and_return(tim)
      allow(controller).to receive(:current_company).and_return(tim.company)
    end

    it "should not allow to create" do
      post :create, params: { name: 'sample key', key: generated_key }, format: :json
      error = JSON.parse(response.body)["errors"][0]
      expect(response.status).to eq(403)
      expect(response.message).to eq("Forbidden")
      expect(error["details"]).to eq("You are not authorized to access this page.")
    end

    it "should not allow to delete" do
      created_key = FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)
      delete :destroy, params: { id: created_key.id }, format: :json
      error = JSON.parse(response.body)["errors"][0]
      expect(response.status).to eq(403)
      expect(response.message).to eq("Forbidden")
      expect(error["details"]).to eq("You are not authorized to access this page.")
    end

    it "should not allow to get all the api keys against the company" do
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)
      FactoryGirl.create(:api_key, edited_by_id: user.id, company_id: user.company.id)

      get :index, format: :json
      expect(response.status).to eq(403)
    end
  end
end
