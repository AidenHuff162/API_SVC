require 'rails_helper'

RSpec.describe Api::V1::PaperworkRequestsController, type: :controller do

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
  let!(:document_with_paperwork_request_and_template) { create(:document_with_paperwork_request_and_template, company: company) }

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

      context 'if current user has no access' do
        it "should not let user get his own paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user1)
          user1.update(user_role_id: no_access_role.id)

          get :index, format: :json
          expect(response).to have_http_status(204)
        end

        it "should not allow manager to get his mangee paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user)
          user.update(user_role_id: no_access_role.id)

          get :index, format: :json      
          expect(response).to have_http_status(204)
        end

        it "should return 204 status if super_admin has no access" do
          super_admin.update(user_role_id: no_access_role.id)
          get :index, params: { user_id: user1.id }, format: :json

          expect(response.status).to eq(204)
        end
        
        it "should return 204 status if admin has no access" do
          admin.update(user_role_id: no_access_role.id)
          allow(controller).to receive(:current_user).and_return(admin)
          get :index, params: { user_id: user1.id }, format: :json

          expect(response.status).to eq(204)
        end
        it "should return 204 status to view other user paperwork request if admin has view only access" do
          allow(controller).to receive(:current_user).and_return(admin)
          admin.update(user_role_id: admin_view_role.id)
          get :index, params: { user_id: user1.id }, format: :json

          expect(response.status).to eq(204)
        end

        it "should return 204 status view own paperwork request if employee has view only access" do
          user1.update(user_role_id: only_view_role.id)
          allow(controller).to receive(:current_user).and_return(user1)
          get :index, params: { user_id: user1.id }, format: :json

          expect(response.status).to eq(200)
        end
      end

    end

    context 'should return paperwork_request' do
      context 'if current user is super admin and has permissions' do
        it "should return 200 status and 24 keys of paperwork_request and valid keys of paperwork_request" do
          get :index, params: { user_id: user1.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result[0].keys.count).to eq(24)
          expect(@result[0].keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "co_signer_type", "state", "document", "paperwork_packet", "user"])
        end
      end

      context 'if current user is manager and has permissions' do
        it "should return 200 status and 24 keys of paperwork_request and valid keys of paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user)
          user.update(user_role_id: only_view_role.id)
          get :index, params: { user_id: user1.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result[0].keys.count).to eq(24)
          expect(@result[0].keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "co_signer_type", "state", "document", "paperwork_packet", "user"])
        end
      end
    end
  end

  describe 'get #signature' do
    context 'should not return paperwork_request' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        
        get :signature, params: { id: paperwork_request.id }, format: :json
        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :signature, params: { id: paperwork_request.id }, format: :json
        expect(response.status).to eq(404)
      end

      context 'if current user has no access' do
        it "should not allow manager to get his mangee paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user)

          get :signature, params: { id: paperwork_request.id }, format: :json      
          expect(response).to have_http_status(204)
        end
      end

    end

    context 'should return paperwork_request' do
      context 'if current user is super admin' do
        it "should return 200 status and 25 keys of paperwork_request and valid keys of paperwork_request" do
          get :signature, params: { id: paperwork_request.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result.keys.count).to eq(25)
          expect(@result.keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user"])
        end
        
        it "should return 3000 status and error if document is not present" do
          get :signature, params: { id: paperwork_request.id, email: user1.email }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(3000)
          expect(@result['errors']).to eq("Signature request Document not found to be signed")
        end

      end

      context 'if current user is employee and get own paperwork_request' do
        it "should return 200 status and 25 keys of paperwork_request and valid keys of paperwork_request" do
          allow(controller).to receive(:current_user).and_return(user1)
          
          get :signature, params: { id: paperwork_request.id }, format: :json

          @result = JSON.parse(response.body)
          expect(response.status).to eq(200)
          expect(@result.keys.count).to eq(25)
          expect(@result.keys).to eq(["id", "hellosign_signature_id", "hellosign_signature_request_id", "hellosign_claim_url", "hellosign_signature_url", "is_signed", "user_id", "signed_document_url", "paperwork_packet_id", "template_ids", "sign_date", "unsigned_document_url", "is_assigned", "is_all_signed", "paperwork_packet_deleted", "description", "co_signer_id", "paperwork_packet_type", "send_completion_email", "company_id", "co_signer_type", "state", "document", "paperwork_packet", "user"])
        end
      end
    end
  end

  describe 'get #download_document_url' do
    context 'should not return download url' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :download_document_url, params: { id: paperwork_request.id }, format: :json

        expect(response.status).to eq(401)
      end
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :download_document_url, params: { id: paperwork_request.id }, format: :json
       
        expect(response.status).to eq(404)
      end

      context 'if current user has no access' do
        it "should not let user get download url" do
          allow(controller).to receive(:current_user).and_return(user1)
          user1.update(user_role_id: no_access_role.id)
          get :download_document_url, params: { id: paperwork_request.id }, format: :json

          expect(response).to have_http_status(204)
        end

        it "should not allow manager to get his mangee download url" do
          allow(controller).to receive(:current_user).and_return(user)
          user.update(user_role_id: no_access_role.id)
          get :download_document_url, params: { id: paperwork_request.id }, format: :json      

          expect(response).to have_http_status(204)
        end

        it "should return 204 status if super_admin has no access" do
          super_admin.update(user_role_id: no_access_role.id)
          get :download_document_url, params: { id: paperwork_request.id }, format: :json

          expect(response.status).to eq(204)
        end
        
        it "should return 204 status if admin has no access" do
          admin.update(user_role_id: no_access_role.id)
          allow(controller).to receive(:current_user).and_return(admin)
          get :download_document_url, params: { id: paperwork_request.id }, format: :json

          expect(response.status).to eq(204)
        end

        it "should return 204 status to view other user paperwork request if admin has view only access" do
          allow(controller).to receive(:current_user).and_return(admin)
          admin.update(user_role_id: admin_view_role.id)
          get :download_document_url, params: { id: paperwork_request.id, user_id: user1.id }, format: :json

          expect(response.status).to eq(204)
        end

        it "should return 204 status view own paperwork request if employee has view only access" do
          user1.update(user_role_id: only_view_role.id)
          allow(controller).to receive(:current_user).and_return(user1)
          get :download_document_url, params: { id: paperwork_request.id }, format: :json

          expect(response.status).to eq(200)
        end

        it "should return 200 status view own paperwork request if employee has view only access" do
          allow(controller).to receive(:current_user).and_return(super_admin)
          paperwork_request = document_with_paperwork_request_and_template.paperwork_requests.first
          paperwork_request.update(state: 'assigned')
          get :download_document_url, params: { id: paperwork_request.id }, format: :json

          expect(response.status).to eq(200)
        end
      end

    end

    context 'should return download url' do
      context 'if current user is super admin and has permissions' do
        it "should return 200 status response url" do
          result = get :download_document_url, params: { id: paperwork_request.id }, format: :json
          expect(response).to have_http_status(200)
          response = JSON.parse(result.body)
          expect(response['url']).to eq(paperwork_request.signed_document.url)
        end
      end

      context 'if current user is manager and has permissions' do
        it "should return 200 status response url" do
          allow(controller).to receive(:current_user).and_return(user)
          user.update(user_role_id: only_view_role.id)
          
          result = get :download_document_url, params: { id: paperwork_request.id }, format: :json
          expect(response).to have_http_status(200)
          response = JSON.parse(result.body)
          expect(response['url']).to eq(paperwork_request.signed_document.url)
        end
      end
      context 'should let user download his own document' do
        it "should return 200 status response url" do
          allow(controller).to receive(:current_user).and_return(user1)
            
          result = get :download_document_url, params: { id: paperwork_request.id }, format: :json
          expect(response).to have_http_status(200)
          response = JSON.parse(result.body)
          expect(response['url']).to eq(paperwork_request.signed_document.url)
        end
      end
    end
  end

  describe 'post #signed_paperwork' do
    context 'should not receive signed paperwork event' do
      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        post :signed_paperwork, params: { id: paperwork_request_cosigner.id }, format: :json
        expect(response.status).to eq(404)
      end
    end

    context 'should receive signed paperwork event' do
      before do
        @draft_response = (double('data', :data => {'signatures' => [{"signer_email_address" => "#{user1.email}", "signature_id" => "123"}], "sign_url" => "test.com"}))
        allow(HelloSign).to receive(:signature_request_files)
        .with(signature_request_id: paperwork_request.hellosign_signature_request_id).and_return(@draft_response)
      end
      
      context 'if current_user is not present' do 
        it "should allow co-signer to get his own paperwork_request" do
          allow(controller).to receive(:current_user).and_return(nil)
          post :signed_paperwork, params: { json: {"event": {"event_type": "signature_request_all_signed"}, "signature_request": {"signature_request_id": 123}}.to_json }, format: :json
          expect(response).to have_http_status(200)
          expect(response.body).to eq('Hello API Event Received')
        end
      end
      
      context 'if event is signature_request_all_signed' do
        it "should return 200 status and 22 keys of paperwork_request and valid keys of paperwork_request" do
          post :signed_paperwork, params: { json: {"event": {"event_type": "signature_request_all_signed"}, "signature_request": {"signature_request_id": 123}}.to_json }, format: :json
          expect(response).to have_http_status(200)
          expect(response.body).to eq('Hello API Event Received')
        end
      end

      context 'if event is signature_request_downloadable' do
        it "should return 200 status and 22 keys of paperwork_request and valid keys of paperwork_request" do
          post :signed_paperwork, params: { json: {"event": {"event_type": "signature_request_downloadable"}, "signature_request": {"signature_request_id": 123}}.to_json }, format: :json
          expect(response).to have_http_status(200)
          expect(response.body).to eq('Hello API Event Received')
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