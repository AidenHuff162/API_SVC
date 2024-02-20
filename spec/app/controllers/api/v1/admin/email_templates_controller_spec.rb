require 'rails_helper'

RSpec.describe Api::V1::Admin::EmailTemplatesController, type: :controller do

  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
  end

  describe "POST #create" do
    it "should create email template of welcome type" do
      post :create, params: { email_type: 'welcome_email', name: 'Welcome Email', subject: 'Welcome Subject',
      description: 'Welcome Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of invitation type" do
      post :create, params: { email_type: 'invitation', name: 'Invitation Email', subject: 'Invitation Subject',
      description: 'Invitation Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of offboarding type" do
      post :create, params: { email_type: 'offboarding', name: 'Off boarding Email', subject: 'Off boarding Subject',
      description: 'Off boarding Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of new pending hire type" do
      post :create, params: { email_type: 'new_pending_hire', name: 'New Pending Hire Email', subject: 'New Pending Hire Subject',
      description: 'New Pending Hire Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of preboarding type" do
      post :create, params: { email_type: 'preboarding', name: 'Preboarding Email', subject: 'Preboarding Subject',
      description: 'Preboarding Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of manager form type" do
      post :create, params: { email_type: 'manager_form', name: 'Manager Form Email', subject: 'Manager Form Subject',
      description: 'Manager Form Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of new activities assigned type" do
      post :create, params: { email_type: 'new_activites_assigned', name: 'New Activities Assigned Email', subject: 'New Activities Assigned Subject',
      description: 'New Activities Assigned Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of new manager form type" do
      post :create, params: { email_type: 'new_manager_form', name: 'New Manager Form Email', subject: 'New Manager Form Subject',
      description: 'New Manager Form Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of new manager type" do
      post :create, params: { email_type: 'new_manager', name: 'New Manager Email', subject: 'New Manager Subject',
      description: 'New Manager Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of new buddy type" do
      post :create, params: { email_type: 'new_buddy', name: 'New Buddy Email', subject: 'New Buddy Subject',
      description: 'New Buddy Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of start date change type" do
      post :create, params: { email_type: 'start_date_change', name: 'Start Date Change Email', subject: 'Start Date Change Subject',
      description: 'Start Date Change Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of on boarding activity notification type" do
      post :create, params: { email_type: 'onboarding_activity_notification', name: 'On boarding Activity Notification Email', subject: 'On boarding Activity Notification Subject',
      description: 'On boarding Activity Notification Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of transition activity notification type" do
      post :create, params: { email_type: 'transition_activity_notification', name: 'Transition Activity Notification Email', subject: 'Transition Activity Notification Subject',
      description: 'Transition Activity Notification Description' }, format: :json
      expect(response.message).to eq('Created')
    end

    it "should create email template of off boarding activity notification type" do
      post :create, params: { email_type: 'offboarding_activity_notification', name: 'Off boarding Activity Notification Email', subject: 'Offboarding Activity Notification Subject',
      description: 'Off boarding Activity Notification Description' }, format: :json
      expect(response.message).to eq('Created')
    end
  end

  describe '#paginated' do
    it 'return ok status' do
      get :paginated, params: { start: '0', length: '25', order: {"0": {column: "1", dir: "desc"}}, search: {value: ""}}
      expect(response).to have_http_status(200)
    end
  end

  describe '#index' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}
    let!(:email_template_dup) {create(:email_template, company: peter.company, name: "another invite")}

    it 'return collection for user emails' do
      get :index, params: {sub_tab: "emails", user_id: peter.id, inbox_feature_flag: true, format: "json"}
      collection = JSON.parse response.body
      expect(collection.length).to eq(3)
    end
    
    it 'return collection for tab scheduled emails' do
      get :index, params: {sub_tab: "emails", tab: "scheduled", inbox_feature_flag: true, format: "json"}
      collection = JSON.parse response.body
      expect(collection.length).to eq(3)
    end
    
    it 'return collection for company emails' do
      get :index, params: {sub_tab: "emails", format: "json"}
      collection = JSON.parse response.body
      expect(collection.length).to eq(company.email_templates.length)
    end

    it 'return collection for company emails' do
      get :index, params: {sub_tab: "emails", email_type: "offboarding", user_id: peter.id, format: "json"}
      collection = JSON.parse response.body
      expect(response.status).to eq(200)
    end
  end

  describe '#update' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'update collection for user emails' do
      put :update, params: { id: email_template.id, email_type: 'welcome_email', name: 'Welcome Email', subject: 'Welcome Subject',
      description: 'Welcome Description' }, format: :json
      res = JSON.parse response.body
      expect(res.present?).to eq(true)
    end
  end

  describe '#destroy' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'destroy collection for user emails' do
      delete :destroy, params: { id: email_template.id }, format: :json
      expect(response.status).to eq(204)
    end
  end

  describe '#send_test_email' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'send_test_email  for user emails' do
      put :send_test_email, params: { id: email_template.id, email_type: 'welcome_email', name: 'Welcome Email', subject: 'Welcome Subject',
      description: 'Welcome Description' }, format: :json
      expect(response.status).to eq(200)
    end
  end

  describe '#duplicate_template' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'duplicate_template for user emails' do
      post :duplicate_template, params: { id: email_template.id }, format: :json
      res = JSON.parse response.body
      expect(res.present?).to eq(true)
      expect(response.status).to eq(201)
    end
  end

  describe '#filter_templates' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'filter_templates for user emails' do
      get :filter_templates, params: { id: email_template.id }, format: :json
      res = JSON.parse response.body
      expect(res.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end

  describe '#get_bulk_onboarding_emails' do
    let!(:peter) {create(:peter, current_stage: :registered, role: "employee", title: "Software Engineer", company: company)}
    let!(:email_template) {create(:email_template, company: peter.company)}

    it 'get_bulk_onboarding_emails for user emails' do
      get :get_bulk_onboarding_emails, params: { id: email_template.id, user_id: peter.id }, format: :json
      res = JSON.parse response.body
      expect(res.present?).to eq(true)
      expect(response.status).to eq(200)
    end
  end
end
