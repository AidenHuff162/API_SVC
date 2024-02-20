require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe Api::V1::Admin::PaperworkRequestsController, type: :controller do
  include ActiveJob::TestHelper

  let(:company) { create(:company, document_completion_emails: true) }
  let(:no_access_role) { create(:with_no_access_for_all, role_type: 1, company: company) }
  let(:only_view_role) { create(:with_view_access_for_all, role_type: 1, company: company) }
  let(:admin_view_role) { create(:with_view_access_for_all, role_type: 2, company: company) }
  let(:view_edit_role) { create(:with_view_and_edit_access_for_all, role_type: 1, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company) }
  let(:co_signer) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company, manager: user) }
  let(:super_admin) { create(:sarah, account_creator: user, company: company) }
  let(:admin) { create(:peter, company: company) }
  let(:user1) { create(:user, state: :active, current_stage: :registered, role: 'employee', account_creator: super_admin, company: company, manager: user) }
  let(:doc) { create(:document, company: company) }
  let(:other_company) { create(:company, subdomain: 'boo') }
  let(:other_user) { create(:user, company: other_company) }
  let!(:paperwork_request) { create(:paperwork_request, :request_skips_validate, document: doc, user: user1, state: "signed", hellosign_signature_request_id: 123) }
  let!(:paperwork_request_cosigner) { create(:paperwork_request, :request_skips_validate, document: doc, user: user1, state: "all_signed", co_signer_id: co_signer.id) }
  let(:paperwork_template) { create(:paperwork_template, :template_skips_validate, document_id: doc.id, company_id: company.id) } 

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(super_admin)
  end

  describe 'get #index' do
    context 'should not return paperwork_requests' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :index, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :index, format: :json

        expect(response.status).to eq(404)
      end
    end

    context 'should return paperwork_request' do
      context 'if current user is super admin' do
        it "should return 200 status and 26 keys of paperwork_request and valid keys of paperwork_request" do
          get :index, params: { user_id: user1.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result[0].keys.count).to eq(26)
          expect(@result[0].keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user", "co_signer"])
        end
      end

      context 'if current user is manager' do
        it "should return 200 status and 26 keys of paperwork_request and valid keys of paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user)
          get :index, params: { user_id: user1.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result[0].keys.count).to eq(26)
          expect(@result[0].keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user", "co_signer"])
        end
      end

      context 'if current user is employee' do
        it "should return 200 status and 26 keys of paperwork_request and valid keys of paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user1)
          get :index, params: { user_id: user1.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result[0].keys.count).to eq(26)
          expect(@result[0].keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user", "co_signer"])
        end
      end
    end
  end

  describe 'post #assign' do
    context 'should not assign paperwork_request' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :assign, params: { paperwork_requests: [{id: paperwork_request_cosigner.id, user: {id: paperwork_request_cosigner.user.id}}] }, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :assign, params: { paperwork_requests: [{id: paperwork_request_cosigner.id, user: {id: paperwork_request_cosigner.user.id}}] }, format: :json

        expect(response.status).to eq(404)
      end
    end

    context 'should assign paperwork_request' do
      context 'if current_user is employee' do 
        it "should allow employee to assign paperwork_request and enqueue UnsignedDocumentJob " do
          allow(controller).to receive(:current_user).and_return(user1)
          post :assign, params: { paperwork_requests: [{id: paperwork_request_cosigner.id, user: {id: paperwork_request_cosigner.user.id}}] }, format: :json

          expect(response).to have_http_status(201)
          expect(HellosignCall.where("api_end_point = ? AND state = ? AND paperwork_request_id = ?",'signature_request_files',HellosignCall.states[:in_progress], paperwork_request_cosigner.id).count).to eq(1)
        end
      end

      context 'if current user is super admin' do
        it "should allow super admin to assign paperwork_request and enqueue UnsignedDocumentJob " do
          post :assign, params: { paperwork_requests: [{id: paperwork_request.id, user: {id: paperwork_request.user.id}}] }, format: :json

          expect(response.status).to eq(201)
          expect(HellosignCall.where("api_end_point = ? AND state = ? AND paperwork_request_id = ?",'signature_request_files',HellosignCall.states[:in_progress], paperwork_request.id).count).to eq(1)
        end
      end
    end
  end

  describe 'post #bulk_paperwork_request_assignment' do
    context 'should not assign bulk paperwork_request' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :bulk_paperwork_request_assignment, params: { paperwork_template_id: paperwork_template.id, users: [user, user1] }, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :bulk_paperwork_request_assignment, params: { paperwork_template_id: paperwork_template.id, users: [user, user1] }, format: :json

        expect(response.status).to eq(404)
      end
    end

    context 'should assign bulk paperwork_request' do
      context 'if current_user is employee' do 
        it "should allow employee to assign bulk paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user1)
          Sidekiq::Queues["bulk_paperwork_request_assignment"].clear
          post :bulk_paperwork_request_assignment, params: { paperwork_template_id: paperwork_template.id, users: [user, user1] }, format: :json

          expect(response.status).to eq(204)
          expect(Sidekiq::Queues["bulk_paperwork_request_assignment"].size).to eq(1)
       end
      end

      context 'if current user is super admin' do
        it "should assign bulk paperwork_request" do
          Sidekiq::Queues["bulk_paperwork_request_assignment"].clear
          post :bulk_paperwork_request_assignment, params: { paperwork_template_id: paperwork_template.id, users: [user, user1] }, format: :json

          expect(response.status).to eq(204)
          expect(Sidekiq::Queues["bulk_paperwork_request_assignment"].size).to eq(1)
        end
      end
    end
  end
  
  describe 'post #create' do
    context 'should not create paperwork_request' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { id: paperwork_request_cosigner.id }, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :create, params: { id: paperwork_request_cosigner.id }, format: :json

        expect(response.status).to eq(404)
      end
      it 'should return unprocessible entity HelloSign is not configured' do
        post :create, params: { document_id: doc.id, user_id: user1.id, state: "signed" }, format: :json
        expect(response.status).to eq(422)
      end

      it "should return error message and 3000 status if cosigner id is same as user id" do
        allow(controller).to receive(:current_user).and_return(user)
        post :create, params: { document_id: doc.id, user_id: user1.id, co_signer_id: user1.id, state: "signed" }, format: :json

        result = JSON.parse(response.body)
        expect(response).to have_http_status(3000)
        expect(result['errors']).to eq("Cosigner must be different")
      end
    end

    context 'should create paperwork_request' do
      before do
        @draft_response = (double('data', :data => {'signature_request_id' => 1, 'claim_url'=> 'url'}))
        allow(HelloSign).to receive(:create_embedded_unclaimed_draft)
          .with(test_mode: company.get_hellosign_test_mode,
            client_id: Sapling::Application::HELLOSIGN_CLIENT_ID,
            type: 'request_signature',
            subject: doc.title,
            message: doc.description,
            requester_email_address: user.email,
            :files => [nil],
            is_for_embedded_signing: 1,
            signers:  [{:email_address=>user1.email, :name=>user1.full_name, :role=>"employee", :order=>0}]).and_return(@draft_response)
      end
      
      context 'if current user has no access' do
        it "should allow any user to create paperwork_request and return 26 keys count and valid keys" do
          allow(controller).to receive(:current_user).and_return(user)
          post :create, params: { document_id: doc.id, user_id: user1.id, state: "signed" }, format: :json

          result = JSON.parse(response.body)
          expect(response).to have_http_status(201)
          expect(result.keys.count).to eq(26)
          expect(result.keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user", "co_signer"])
        end
      end

    end
  end
  
  describe 'delete #destroy' do
    context 'should not delete paperwork_request' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: paperwork_request_cosigner.id }, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        delete :destroy, params: { id: paperwork_request_cosigner.id }, format: :json

        expect(response.status).to eq(404)
      end
    end

    context 'should return paperwork_request' do
      context 'if current user has no access' do
        it "should allow any user to delete his mangee paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user)
          post :destroy, params: { id: paperwork_request_cosigner.id }, format: :json

          expect(response).to have_http_status(201)
        end

        it "should delete other user paperwork request and delete fix count" do
          size = user1.paperwork_requests.count
          delete :destroy, params: { id: paperwork_request.id, user_id: paperwork_request.user_id }, format: :json
          
          expect(response).to have_http_status(201)
          expect(user1.paperwork_requests.count).to eq(size-1)
        end
      end
      
      context 'if current_user is co_signer' do 
        it "should allow co-signer to delete his own paperwork_request" do
          allow(controller).to receive(:current_user).and_return(co_signer)
          delete :destroy, params: { id: paperwork_request_cosigner.id, user_id: paperwork_request_cosigner.user_id }, format: :json

          expect(response).to have_http_status(201)
        end
      end
    end
  end
end