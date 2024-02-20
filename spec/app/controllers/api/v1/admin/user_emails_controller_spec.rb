require 'rails_helper'

RSpec.describe Api::V1::Admin::UserEmailsController, type: :controller do

  let(:company2) { create(:company) }
  let(:company) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company2) }
  let(:sarah) { create(:sarah, company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(sarah)
    allow(controller).to receive(:current_company).and_return(company)
  end

  describe "#create" do
    it "creates test email" do
      response = post :create, params: { user_id: sarah.id, subject: "[Test Email] <p>asd</p>", cc: nil, bcc: nil, description: "<p>yoy</p>", invite_at: nil, is_daylight_save: nil, test: false, email_type: 'invitation' }, format: :json
      expect(response.status).to eq 200
    end

    it 'allows sarah to manage user email' do
      ue = create(:user_email, user: sarah)
      ability = Ability.new(sarah)
      assert ability.can?(:manage, ue)
    end

    it 'does not allow user from different company to manage emails' do
      ue = create(:user_email, user: sarah)
      ability = Ability.new(user)
      assert ability.cannot?(:manage, ue)
    end

    it 'create incomplete email' do
      response = post :create_incomplete_email, params: { user_id: sarah.id, subject: "[Test Email] <p>asd</p>", cc: nil, bcc: nil, description: "<p>yoy</p>", invite_at: nil, is_daylight_save: nil, test: false, email_type: 'invitation' }, format: :json
      expect(response.status).to eq 200
    end

    it 'create_default_onboarding_emails' do
      response = post :create_default_onboarding_emails, params: { user_id: sarah.id }, format: :json
      expect(response.status).to eq 200
    end

    it 'create_default_offboarding_emails' do
      response = post :create_default_offboarding_emails, params: { user_id: sarah.id }, format: :json
      expect(response.status).to eq 200
    end
  end

  describe "#delete_incomplete_email" do
    it "delete incomplete email" do
      response = post :delete_incomplete_email, params: { user_id: sarah.id }, format: :json
      expect(response.status).to eq 200
    end
  end

  describe "#emails_paginated" do
    it "return paginated email" do
      response = get :emails_paginated, params: { user_id: sarah.id, start: 0, length: 10, order_column: 0, order_in: 'asc', order: {'0': {dir: 'asc', column: 0 } } }, format: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
  end

  describe "#show" do
    let(:user_email) { create(:user_email, user: sarah) }
    it "return email" do
      response = get :show, params: { id: user_email.id }, format: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
  end

  describe "#schedue_email" do
    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 1} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2, relative_key: 'start date', due: 'after', duration: 5, duration_type: 'minutes'} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2, relative_key: 'last day worked', due: 'on', duration: 5, duration_type: 'minutes'} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2, relative_key: 'date of termination', due: 'on', duration: 5, duration_type: 'minutes'} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2, relative_key: 'birthday', due: 'before', duration: 5, duration_type: 'minutes'} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
    
    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 2, relative_key: 'anniversary', due: 'before', duration: 5, duration_type: 'minutes'} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end

    it "schedule email" do
      response = post :schedue_email, params: { user_id: sarah.id, schedule_options: {inbox_feature_flag: true, send_email: 0} }, as: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
  end

  describe "#update" do
    let(:user_email) { create(:user_email, user: sarah) }
    it "update email" do
      response = put :update, params: { id: user_email.id, schedule_options: {inbox_feature_flag: true} }, format: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
  end

  describe "#destroy" do
    let(:user_email) { create(:user_email, user: sarah) }
    it "destroy email" do
      response = delete :destroy, params: { id: user_email.id }, format: :json
      expect(response.status).to eq 200
    end
  end

  describe "#restore" do
    let(:user_email) { create(:user_email, user: sarah) }
    it "restore email" do
      user_email.destroy
      response = put :restore, params: { id: user_email.id }, format: :json
      expect(response.body.present?).to eq true
      expect(response.status).to eq 200
    end
  end
end
