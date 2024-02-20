require 'rails_helper'

RSpec.describe Api::V1::UserDocumentConnectionsController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :invited, company: company) }
  let(:document_connection_relation) { create(:document_connection_relation) }
  let(:document_upload_request) { create(:document_upload_request, document_connection_relation: document_connection_relation, company_id: company.id, user_id: user.id, special_user_id: user.id) }
  let(:attachment) { create(:document_upload_request_file) }
  let!(:user_document_connection) { create(:user_document_connection, user: user, created_by: user, document_connection_relation: document_connection_relation, attached_files: [attachment]) }

  before do
    # sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "GET #index" do
    it 'should return user document connections' do
      get :index, params: {user_id: user.id, company_id: company.id}, format: :json
      JSON.parse(response.body)
      expect(response.status).to eq(200)
    end
  end

  describe "PUT #update" do
    it 'should update the user document connection' do
      put :update, params: { id: user_document_connection.id, user_id: user.id }, format: :json
      expect(user_document_connection.present?).to eq(true)
    end

    it 'should create history' do
      expect{put :update, params: { id: user_document_connection.id, user_id: user.id }, format: :json}.to change{History.count}.by (1)
    end
  end

  describe "DELETE #destroy" do
    it 'should delete the user document connection' do
      delete :destroy, params: { id: user_document_connection.id}, format: :json
      expect(response.status).to eq(204)
    end
  end 
end
