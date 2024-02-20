require 'rails_helper'

RSpec.describe Api::V1::Admin::PaperworkTemplatesController, type: :controller do

  let(:company) { create(:company, subdomain: 'paperwork-template-ctrl') }
  let(:document1) { create(:document_with_drafted_paperwork_template, company_id: company.id) }
  let(:document2) { create(:document_with_paperwork_template, company_id: company.id) }
  let(:document3) { create(:document, company_id: company.id) }
  let(:sarah) { create(:sarah, company: company) }
  let(:peter) { create(:peter, company: company) }
  let(:nick) { create(:nick, company: company) }
  let(:tim) { create(:tim, company: company, manager: nick) }
  let(:other_company) { create(:company, subdomain: 'paperwork-template-ctrl1') }
  let(:other_user) { create(:user, company: other_company) }

  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'GET #show' do
    context 'should not show paperwork templates' do
      it 'should return not return template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :show, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return not return template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        get :show, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should return not return template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        get :show, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
      end
    end

    context 'should show paperwork templates' do
      it 'should return ok status and template if requester is super admin' do
        get :show, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['document']['id']).to eq(document1.id)
      end

      it 'should return ok status and template if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        get :show, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['document']['id']).to eq(document1.id)
      end

      it 'should return ok status and template if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        get :show, params: { id: document2.paperwork_template.id }, format: :json
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['document']['id']).to eq(document2.id)
      end
    end
  end

  describe 'POST #finalize' do
    context 'should not finalize paperwork template' do
      it 'should return not finalize template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should not create history for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return not finalize template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return not finalize template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not create history for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return no content status and do not finalize template if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.reload.draft?).to eq(true)
      end

      it 'should not create history if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end
    end

    context 'should show paperwork templates' do
      it 'should return nothing status and finalize template if requester is super admin' do
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(201)
        expect(document1.paperwork_template.reload.saved?).to eq(true)
      end

      it 'should create history if requester is super admin' do
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (1)
      end

      it 'should return nothing status and finalize template if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        post :finalize, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(201)
        expect(document1.paperwork_template.reload.saved?).to eq(true)
      end

      it 'should create history if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        expect{post :finalize, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (1)
      end
    end
  end

  describe 'PUT #update' do
    context 'should not update paperwork template' do
      it 'should not update template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(401)
        expect(document1.paperwork_template.reload.representative_id).to eq(nil)
      end

      it 'should not update template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.reload.representative_id).to eq(nil)
      end

      it 'should not update template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.reload.representative_id).to eq(nil)
      end

      it 'should return no content status and not update template if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.reload.representative_id).to eq(nil)
      end
    end

    context 'should update paperwork templates' do
      it 'should return ok status and update template if requester is super admin' do
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(document1.paperwork_template.reload.representative_id).to eq(tim.id)
      end

      it 'should return ok status and update template if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        put :update, params: { id: document1.paperwork_template.id, representative_id: tim.id }, format: :json
        expect(response.status).to eq(200)
        expect(document1.paperwork_template.reload.representative_id).to eq(tim.id)
      end
    end
  end

  describe 'GET #smart_basic_index' do
    context 'should get api status based on auth/unauth and company' do

      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :smart_basic_index, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :smart_basic_index, format: :json
        expect(response.status).to eq(404)
      end

      it 'should return collection data ' do
        get :smart_basic_index, params: {skip_pagination: true }, format: :json
        result = JSON.parse(response.body)
        expect(response.status).to eq(200)
      end

    end
  end

  describe 'GET #basic_index' do

    context 'authorize/ unauthorize api response' do

      it 'should return unauthorised status if current user is nil' do
        allow(controller).to receive(:current_user).and_return(nil)
        get :smart_basic_index, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :basic_index, format: :json
        expect(response.status).to eq(404)
      end

      it 'should return status if company available' do
        get :basic_index, params: {skip_pagination: true }, format: :json
        expect(response.status).to eq(200)
      end

    end
  end


  describe 'DELETE #destroy' do
    before do
       stub_request(:post, "https://api.hellosign.com/v3/template/delete/MyString").
         with(
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'Basic NzA0ZmM5OGM4NmY2ODNiNDhjNTZmZDFkODI0ODdkM2QxNDhmODVhN2Y4ZjEwNmM4MGI0MmU3ZWIxNTkxMmQ1ZDo=',
          'Content-Length'=>'0',
          'User-Agent'=>'hellosign-ruby-sdk/3.5.1'
           }).
         to_return(status: 200, body: "", headers: {})
    end
    context 'should not destroy paperwork template' do
      it 'should not destroy template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(401)
        expect(document1.paperwork_template.deleted_at).to be_nil
      end

      it 'should not create history for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should not destroy template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.deleted_at).to be_nil
      end

      it 'should not create history for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should not destroy template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.deleted_at).to be_nil
      end

      it 'should not create history for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return no content status and not destroy template if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(204)
        expect(document1.paperwork_template.deleted_at).to be_nil
      end

      it 'should not create history if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (0)
      end
    end

    context 'should update paperwork templates' do
      it 'should destroy template if requester is super admin' do
        allow(HelloSign).to receive(:delete_template)
        .with(template_id: document1.paperwork_template.hellosign_template_id).and_return('template_deleted')
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(201)
        expect(document1.paperwork_template.reload.deleted_at).not_to be_nil
      end

      it 'should create history if requester is super admin' do
        allow(HelloSign).to receive(:delete_template)
        .with(template_id: document1.paperwork_template.hellosign_template_id).and_return('template_deleted')
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (1)
      end

      it 'should destroy template if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        allow(HelloSign).to receive(:delete_template)
        .with(template_id: document1.paperwork_template.hellosign_template_id).and_return('template_deleted')
        delete :destroy, params: { id: document1.paperwork_template.id }, format: :json
        expect(response.status).to eq(201)
        expect(document1.paperwork_template.reload.deleted_at).not_to be_nil
      end

      it 'should create history if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        allow(HelloSign).to receive(:delete_template)
        .with(template_id: document1.paperwork_template.hellosign_template_id).and_return('template_deleted')
        expect{delete :destroy, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (1)
      end
    end
  end

  describe 'POST #create' do
    context 'should not create paperwork template' do
      it 'should not create template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(401)
        expect(document3.reload.paperwork_template).to be_nil
      end

      it 'should not create history for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should not create template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(204)
        expect(document3.reload.paperwork_template).to be_nil
      end

      it 'should not create history for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should not create template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(204)
        expect(document3.reload.paperwork_template).to be_nil
      end

      it 'should not create history for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (0)
      end

      it 'should return no content status and not create template if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(204)
        expect(document3.reload.paperwork_template).to be_nil
      end

      it 'should not create history if requester is employee' do
        allow(controller).to receive(:current_user).and_return(nick)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (0)
      end
    end

    context 'should create paperwork template' do
      it 'should create template if requester is super admin' do
        allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(201)
        expect(document3.reload.paperwork_template).not_to be_nil
      end

      it 'should create history if requester is super admin' do
        allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (1)
      end

      it 'should create template if requester is admin' do
        allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
        allow(controller).to receive(:current_user).and_return(peter)
        post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json
        expect(response.status).to eq(201)
        expect(document3.reload.paperwork_template).not_to be_nil
      end

      it 'should create history if requester is admin' do
        allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
        allow(controller).to receive(:current_user).and_return(peter)
        expect{post :create, params: { document_id: document3.id, hellosign_template_id: '1212121', company_id: company.id }, format: :json}.to change{History.count}.by (1)
      end
    end
  end

  describe 'POST #get_edit_url' do
    context 'should not get edit url of paperwork template' do
      before do
         stub_request(:post, "https://api.hellosign.com/v3/embedded/edit_url/1212121").
         with(
           body: {"skip_signer_roles"=>"0", "skip_subject_message"=>"0", "template_id"=>"1212121", "test_mode"=>"0"},
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'Basic NzA0ZmM5OGM4NmY2ODNiNDhjNTZmZDFkODI0ODdkM2QxNDhmODVhN2Y4ZjEwNmM4MGI0MmU3ZWIxNTkxMmQ1ZDo=',
          'Content-Type'=>'application/x-www-form-urlencoded',
          'User-Agent'=>'hellosign-ruby-sdk/3.5.1'
           }).
         to_return(status: 200, body: "", headers: {})
      end
      it 'should not get edit url of template for unauthenticated user' do
        allow(controller).to receive(:current_user).and_return(nil)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(401)
      end

      it 'should not get edit url of template for user of other company, current session as other company' do
        allow(controller).to receive(:current_company).and_return(other_company)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should not get edit url of template for user of other company, current session as other user' do
        allow(controller).to receive(:current_user).and_return(other_user)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(204)
      end

      it 'should get error if wrong hello sign template id will be given' do
        allow(controller).to receive(:current_user).and_return(nick)
        @draft_response = (double('data', :data => {"edit_url" => "test.com"}))
        allow(HelloSign).to receive(:get_embedded_template_edit_url)
        .with( template_id: '1212121', skip_signer_roles: PaperworkTemplate::SKIP_ACTION, skip_subject_message: PaperworkTemplate::SKIP_ACTION ).and_return(@draft_response)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(201)
      end
    end

    context 'should get edit url of paperwork template' do
      before do
      stub_request(:post, "https://api.hellosign.com/v3/embedded/edit_url/1212121").
         with(
           body: {"skip_signer_roles"=>"0", "skip_subject_message"=>"0", "template_id"=>"1212121", "test_mode"=>"0"},
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'Basic NzA0ZmM5OGM4NmY2ODNiNDhjNTZmZDFkODI0ODdkM2QxNDhmODVhN2Y4ZjEwNmM4MGI0MmU3ZWIxNTkxMmQ1ZDo=',
          'Content-Type'=>'application/x-www-form-urlencoded',
          'User-Agent'=>'hellosign-ruby-sdk/3.5.1'
           }).
         to_return(status: 200, body: "", headers: {})
      end
      it 'should get edit url of template if requester is super admin' do
        @draft_response = (double('data', :data => {"edit_url" => "test.com"}))
        allow(HelloSign).to receive(:get_embedded_template_edit_url)
        .with(template_id: '1212121', skip_signer_roles: PaperworkTemplate::SKIP_ACTION, skip_subject_message: PaperworkTemplate::SKIP_ACTION).and_return(@draft_response)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(201)
      end

      it 'should get edit url of template if requester is admin' do
        allow(controller).to receive(:current_user).and_return(peter)
        @draft_response = (double('data', :data => {"edit_url" => "test.com"}))
        allow(HelloSign).to receive(:get_embedded_template_edit_url)
        .with(template_id: '1212121', skip_signer_roles: PaperworkTemplate::SKIP_ACTION, skip_subject_message: PaperworkTemplate::SKIP_ACTION).and_return(@draft_response)
        post :get_edit_url, params: { hellosign_template_id: '1212121' }, format: :json
        expect(response.status).to eq(201)
      end
    end
  end

  describe 'GET #index' do
    it "should return paper template" do
      allow(controller).to receive(:current_user).and_return(sarah)
      get :index, params: {skip_pagination: true }, format: :json
      expect(response.status).to eq(200)
    end
  end

  describe 'GET #paginated_collective_documents' do
    it 'should return status if company available' do
      allow(controller).to receive(:current_user).and_return(sarah)
      get :paginated_collective_documents, params: {skip_pagination: true }, format: :json
      expect(response.status).to eq(200)
    end
  end

  describe 'GET #paginated_collective_dashboard_documents' do
    it 'should return status if company available' do
      allow(controller).to receive(:current_user).and_return(sarah)
      get :paginated_collective_dashboard_documents, params: {start: 0, length: '10', sort_order: 'asc', sort_column: 'title', term: nil, page: 1, process_type: 'Overdue Documents' }, format: :json
      expect(response.status).to eq(200)
    end
  end

  describe 'POST #duplicate' do
    it 'should create duplicate template' do
      allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
      post :duplicate, params: { id: document1.paperwork_template.id }, format: :json
      expect(response.status).to eq(201)
    end

    it 'should create history for duplicate template' do
      allow_any_instance_of(PaperworkTemplate).to receive(:create_hellosign_template).and_return(true)
      expect{post :duplicate, params: { id: document1.paperwork_template.id }, format: :json}.to change{History.count}.by (1)
    end
  end
end