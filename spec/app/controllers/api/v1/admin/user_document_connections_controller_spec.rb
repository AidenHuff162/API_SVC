require 'rails_helper'

RSpec.describe Api::V1::Admin::UserDocumentConnectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:sarah) { create(:sarah, company: company) }
  let(:nick) { create(:nick, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }
  let(:document_connection_relation) { create(:document_connection_relation) }
  let(:document_upload_request) { create(:document_upload_request, document_connection_relation: document_connection_relation, company_id: company.id, user_id: sarah.id, special_user_id: sarah.id) }
  let(:attachment) { create(:document_upload_request_file) }
  let(:user_document_connection) { create(:user_document_connection, user: sarah, created_by: sarah, document_connection_relation: document_connection_relation, attached_files: [attachment]) }

  let(:valid_session) { {} }

  before do
    allow(controller).to receive(:current_company).and_return(company)
    create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)
    create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)
    create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)
  end

  describe "UserDocumentConnectionsController methods" do
    it "should create user document connection" do
      allow(controller).to receive(:current_user).and_return(sarah)
      post :create,
      params: { document_connection_relation_id: document_upload_request.document_connection_relation.id,
      user_id: sarah.id },
      format: :json
      expect(response.status).to eq(201)
    end

    it "should not create user document connection when user is unauthenticated" do
      allow(controller).to receive(:current_user).and_return(nil)
      post :create,
      params: { document_connection_relation_id: document_upload_request.document_connection_relation.id,
      user_id: sarah.id },
      format: :json
      expect(response.status).to eq(204)
    end

    it "should return a collection of user document connection" do
      allow(controller).to receive(:current_user).and_return(sarah)
      get :index, params: valid_session, format: :json
      expect(JSON.parse(response.body).length).to eq(3)
    end

    it "should not return a collection of user document connection" do
      allow(controller).to receive(:current_user).and_return(nil)
      get :index, params: valid_session, format: :json
      expect(response.status).to eq(204)
    end

    it "should remove user document connection" do
      allow(controller).to receive(:current_user).and_return(sarah)
      doc = create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)
      delete :destroy, params: { id: doc.id }, format: :json
      expect(response.status).to eq(204)
    end

    it "should not remove user document connection" do
      allow(controller).to receive(:current_user).and_return(nil)
      doc = create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)
      delete :destroy, params: { id: doc.id }, format: :json
      expect(response.status).to eq(204)
    end

    it "should not remove user document connection without ID" do
      allow(controller).to receive(:current_user).and_return(sarah)
      expect{ delete :destroy, format: :json }.to raise_error
    end

    it "should bulk assign documents" do
      allow(controller).to receive(:current_user).and_return(sarah)
      Sidekiq::Testing.inline! do
        user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
        user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")
        doc = create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)

        data_array = []
        data_array.push(user_a.attributes)
        data_array.push(user_b.attributes)
        result = post :bulk_document_assignment, params: { document_connection_relation_id: doc.document_connection_relation_id, users: data_array, created_by_id: sarah.id, company_id: company.id }, format: :json
        expect(result.status).to eq(204)

        expect(UserDocumentConnectionCollection.new({company_id: user_a.company_id, user_id: user_a.id, document_connection_relation_id: doc.document_connection_relation_id}).results.count).to eq(1)
        expect(UserDocumentConnectionCollection.new({company_id: user_b.company_id, user_id: user_b.id, document_connection_relation_id: doc.document_connection_relation_id}).results.count).to eq(1)
      end
    end

    it "should not bulk assign documents" do
      allow(controller).to receive(:current_user).and_return(nil)
      Sidekiq::Testing.inline! do
        user_a = FactoryGirl.create(:user, company: company, email: "userA@test.com")
        user_b = FactoryGirl.create(:user, company: company, email: "userB@test.com")
        doc = create(:user_document_connection, document_connection_relation_id: document_upload_request.document_connection_relation.id, user_id: sarah.id, company_id: company.id)

        data_array = []
        data_array.push(user_a)
        data_array.push(user_b)
        result = post :bulk_document_assignment, params: { document_connection_relation_id: doc, users: data_array, created_by_id: sarah.id, company_id: company.id }, format: :json

        expect(result.status).to eq(204)
      end
    end
  end
end
