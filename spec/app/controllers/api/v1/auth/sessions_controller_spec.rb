require 'rails_helper'

RSpec.describe Api::V1::Auth::SessionsController, type: :controller do

  let(:company) { create(:company) }
  let(:company2) { create(:company, login_type: 'only_sso') }
  let(:user) { create(:user, company: company) }
  let(:deleted_user) { create(:user, company: company, deleted_at: Date.today - 1.day) }
  let(:inactive_user) { create(:user, state: :inactive, company: company) }
  let(:user2) { create(:user, company: company2, start_date: Date.today) }
  let(:admin_user) { create(:peter, company: company) }
  let(:offboard_user) { create(:user, current_stage: :departed , termination_date: Date.today - 10 ,company: company) }
  let(:onboard_user) { create(:taylor, password: nil , company: company) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(user.company)
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end

  describe "user" do
    context "with valid credentials" do
      it "should create user session" do
        response = post :create, params: { email: user.email, password: user.password }, format: :json
        expect(JSON.parse(response.body)['id']).to eq(user.id)
      end
    end
  end

  describe "user" do
    context "should not create user session" do
      it "with correct email and incorrect password" do
        response = post :create, params: { email: user.email, password: '123456' }, format: :json
        expect(response).to have_http_status(455)
      end

      it "with incorrect email and correct password" do
        response = post :create, params: { email: 'wrong_email@test.com', password: user.password }, format: :json
        expect(response).to have_http_status(455)
      end

      it "with incorrect email and incorrect password" do
        response = post :create, params: { email: 'wrong_email@test.com', password: '123456' }, format: :json
        expect(response).to have_http_status(455)
      end

    end

    context "should not create user session' " do
      it "with company login_type 'only_sso" do
        allow(controller).to receive(:current_company).and_return(user2.company)
        response = post :create, params: { email: user2.email, password: user2.password }, format: :json
        expect(response).to have_http_status(455)
      end
    end

    context "with inactive state" do
      it "should not create user session" do
        response = post :create, params: { email: inactive_user.email, password: inactive_user.password }, format: :json
        expect(response).to have_http_status(455)
      end
    end

    context "when deleted" do
      it "should not create user session" do
      deleted_user.reload
      post :create, params: { email: deleted_user.email, password: deleted_user.password }, format: :json
      expect(response).to have_http_status(455)
      end
    end
    context "when off-boarded" do
      it "should not create user session" do
      post :create, params: { email: offboard_user.email, password: offboard_user.password }, format: :json
      expect(response).to have_http_status(455)
      end
    end

    context "when on-boarded" do
      it "should not create user session" do
      post :create, params: { email: onboard_user.email, password: onboard_user.password }, format: :json
      expect(response).to have_http_status(455)
      end
    end
  end
end
