require 'rails_helper'

RSpec.describe Api::V1::Admin::JiraIntegrationsController, type: :controller do

  let(:company) { create(:company, subdomain: 'jira') }
  let(:employee) { create(:user, role: :employee, company: company) }
  let(:sarah) { create(:sarah, company: company) }
  let!(:jira_integration) { create(:jira_integration, jira_complete_status: 'abc', company: company)}
  let(:workstream_with_tasks_list) { create(:workstream_with_tasks_list, company: company) }
  
  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe 'POST #issue_updated' do
    context "should not update issues" do
      it "should return 404 if current_company is nil" do
        allow(controller).to receive(:current_company).and_return(nil)
        post :issue_updated, params: {webhookEvent: "jira:issue_updated", issue: {fields: {status: {name: 'abc'}}}}, format: :json

        expect(response.status).to eq(404)
      end

      it "should return event failed and save webhook with status failed if there is any exception" do
        post :issue_updated, params: {webhookEvent: "jira:issue_updated", issue: {fields: ''}}, format: :json

        expect(response.status).to eq(200)
        expect(response.body).to eq('JIRA Api Event Failed')
      end
    end
    
    context "should update issues" do
      it "should return event Received if there is no exception" do
        post :issue_updated, params: {webhookEvent: "jira:issue_updated", issue: {fields: {status: {name: 'abc'}}}}, format: :json

        expect(response.status).to eq(200)
        expect(response.body).to eq('JIRA Api Event Received')
      end
      it "should save webhook with status success and create history if there is task user connection" do
        task_user_connection = create(:task_user_connection, task: workstream_with_tasks_list.tasks.first, user: employee, jira_issue_id: 1) 
        post :issue_updated, params: {webhookEvent: "jira:issue_updated", issue: {fields: {status: {name: 'abc'}}, id: 1}}, format: :json
        expect(History.where(user_id: employee.id).count).to eq(1)
      end
    end
  end

  describe 'GET #generate_keys' do
    context "should not generate keys" do
      it "should return 404 if current_company is nil" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :generate_keys, format: :json

        expect(response.status).to eq(404)
      end
    end
    
    context "should generate keys" do
      it "should return 200 if current_company is present" do
        get :generate_keys, format: :json

        result = JSON.parse(response.body)
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'GET #initialize_integration' do
    context "should not initialize_integration" do
      it "should return 404 if current_company is nil" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :initialize_integration, format: :json

        expect(response.status).to eq(404)
      end
      it "should return 3000 if JIRA api is not initialized" do
        get :initialize_integration, format: :json

        expect(response.status).to eq(3000)
        expect(JSON.parse(response.body)["errors"]).to eq('Please make sure you have set right credentials in JIRA')
      end
    end
    
    context "should initialize_integration" do
      it "should return 200 if current_company is present" do
        data = (double("authorize_url", :authorize_url => 'test.com'))
        allow_any_instance_of(JIRA::Client).to receive(:request_token).and_return(data)
        get :initialize_integration, format: :json
        
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['json']['url']).to eq('test.com')
      end
    end
  end

  describe 'GET #authorize' do
    context "should not authorize" do
      it "should return 404 if current_company is nil" do
        allow(controller).to receive(:current_company).and_return(nil)
        get :authorize, format: :json

        expect(response.status).to eq(404)
      end
      it "should not set access token, client_secret and  jira_issue_statuses if credentials are not valid" do
        get :authorize, params: {oauth_verifier: 123}, format: :json
        expect(jira_integration.secret_token).to eq(nil)
        expect(jira_integration.client_secret).to eq(nil)
        expect(jira_integration.jira_issue_statuses).to eq([])
      end
       it "should redirect_to integrations page if credentials are not valid" do
        expect(get :authorize, params: {oauth_verifier: 123}, format: :json).to redirect_to("http://" + company.app_domain + "/#/admin/settings/integrations")
      end
    end
    
    context "should authorize" do
      before do
        data = (double("authorize_url", :token => 'token', :secret => 'secret'))
        data1 = (double("body", :body => ["statuses" => ["name"=> "name"], "name" => "issue_name"].to_json))
        allow_any_instance_of(JIRA::Client).to receive(:get).and_return(data1)
        allow_any_instance_of(JIRA::Client).to receive(:init_access_token).and_return(data)
      end

      it "should set access token, client_secret, jira_issue_statuses if credentials are valid" do
        expect(jira_integration.reload.secret_token).to eq(nil)
        expect(jira_integration.reload.client_secret).to eq(nil)
        expect(jira_integration.reload.jira_issue_statuses).to eq([])
        get :authorize, params: {oauth_verifier: 123}, format: :json
        
        expect(jira_integration.reload.secret_token).not_to eq(nil)
        expect(jira_integration.reload.client_secret).not_to eq(nil)
        expect(jira_integration.reload.jira_issue_statuses).not_to eq(nil)
      end
    end
  end

  describe 'delete #destroy' do
    context "should not destroy integration" do
      it "should return 404 if current_company is nil" do
        allow(controller).to receive(:current_company).and_return(nil)
        delete :destroy, params: {id: jira_integration.id}, format: :json

        expect(response.status).to eq(404)
      end
      it "should return 500 if integration unable to destroy" do
        allow_any_instance_of(Integration).to receive(:destroy).and_return(false)
        delete :destroy, params: {id: jira_integration.id}, format: :json

        expect(JSON.parse(response.body)["status"]).to eq(500)
      end
    end
    
    context "should destroy integration" do
      it "should return 200 and delete integration if current_company is present" do
        delete :destroy, params: {id: jira_integration.id}, format: :json

        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body)["status"]).to eq(200)
        expect(company.integrations.find_by(id: jira_integration.id)).to eq(nil)
      end
    end
  end

end
