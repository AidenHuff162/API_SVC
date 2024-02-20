require 'rails_helper'

RSpec.describe Api::V1::Admin::GsheetsController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:sarah, company: company) }
  let(:report) { create(:report, id: 1, company_id: company.id, name: 'Doc Test Report', report_type: 3, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}

  before do
    if ENV['FETCH_ENVS_FROM_REMOTE_URL'] == 'true'
      gsheet_client_id = Google::Auth::ClientId.from_hash(JSON.parse(ENV['GOOGLE_SHEETS_CONFIG']))
    else
      gsheet_client_id = Google::Auth::ClientId.from_file('client_secret_gsheet.json')
    end
    AuthorizeGsheetCredentials.stub(:get_authorizer).and_return(@authorizer = Google::Auth::UserAuthorizer.new(gsheet_client_id, "SCOPE", "ya29.ImCzB-", '/api/v1/gsheet_oauth2callback'))
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "get #export_to_google_sheet" do
    context 'credential are present and credential flag is false than' do
      before do
        @authorizer.stub :get_credentials_from_relation => '{"client_id":"336287239849"}'
      end
      context "default report" do
        before do
          get :export_to_google_sheet, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
      context "turnover report" do
        before do
          get :export_to_google_sheet, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
      context "simple report" do
        before do
          get :export_to_google_sheet, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
    end
    context 'credential are absent and credential falg is false than' do
      before do
        @authorizer.stub :get_credentials => ''
      end
      context "default report" do
        before do
          get :export_to_google_sheet, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
      context "turnover report" do
        before do
          get :export_to_google_sheet, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
      context "simple report" do
        before do
          get :export_to_google_sheet, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
    end
    context 'credential from relation are present and credential flag is true than' do
      before do
        @authorizer.stub :get_credentials_from_relation => '{"client_id":"336287239849"}'
      end
      context "default report" do
        before do
          get :export_to_google_sheet, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
      context "turnover report" do
        before do
          get :export_to_google_sheet, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
      context "simple report" do
        before do
          get :export_to_google_sheet, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
          expect(@response_body["background_processing"]).to eq(false)
        end
      end
    end
    context 'credential from relation are absent and credential falg is true than' do
      before do
        @authorizer.stub :get_credentials_from_relation => ''
      end
      context "default report" do
        before do
          get :export_to_google_sheet, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
      context "turnover report" do
        before do
          get :export_to_google_sheet, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
      context "simple report" do
        before do
          get :export_to_google_sheet, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should be nil" do
          expect(@response_body["response"]).to eq(nil)
          expect(@response_body["background_processing"]).to eq(nil)
        end
      end
    end
  end

  describe "get #get_authorization_status" do
    context "credential flag is false than" do
      before do
        @authorizer.stub :get_credentials => ''
      end
      context "default report" do
        before do
          get :get_authorization_status, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
      context "turnover report" do
        before do
          get :get_authorization_status, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
      context "simple report" do
        before do
          get :get_authorization_status, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
    end
    context "credential flag is true than" do
      before do
        @authorizer.stub :get_credentials_from_relation => '{"client_id":"336287239849.abc.xyz.com"}'
        @authorizer.stub :revoke_authorization_from_relation => true
      end
      context "default report" do
        before do
          get :get_authorization_status, params: {report_id: "default", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
      context "turnover report" do
        before do
          get :get_authorization_status, params: {report_id: "turnover", date_filter: "#{DateTime.now}", filters: "{}"}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
      context "simple report" do
        before do
          get :get_authorization_status, params: {report_id: report.id}, format: :json
          @response_body = JSON.parse(response.body)
        end
        it "should not be nil" do
          expect(@response_body["response"]).not_to eq(nil)
        end
      end
    end
  end
end