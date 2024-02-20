require 'rails_helper'

RSpec.describe Api::V1::Admin::PaperworkPacketsController, type: :controller do
  include ActiveJob::TestHelper

  let(:company) { create(:company, document_completion_emails: true) }
  let(:no_access_role) { create(:with_no_access_for_all, role_type: 1, company: company) }
  let(:only_view_role) { create(:with_view_access_for_all, role_type: 1, company: company) }
  let(:admin_view_role) { create(:with_view_access_for_all, role_type: 2, company: company) }
  let(:view_edit_role) { create(:with_view_and_edit_access_for_all, role_type: 1, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, role: 'employee', company: company) }
  let(:super_admin) { create(:sarah, account_creator: user, company: company) }
  let(:admin) { create(:peter, company: company) }

  before do
    stub_request(:post, "https://api.sendgrid.com/v3/mail/send").to_return(status: 200, body: "", headers: {})
    allow(controller).to receive(:current_company).and_return(company)
    allow(controller).to receive(:current_user).and_return(super_admin)
  end

  describe 'get #index' do
    context 'should not return paperwork_packets' do

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
  end

  describe 'get #basic_index' do
    context 'should not return paperwork_packets' do

      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :basic_index, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return basic index' do
        allow(controller).to receive(:current_company).and_return(company)
        get :basic_index, format: :json
        expect(response.status).to eq(200)
      end

    end
  end

  describe 'get #smart_packet_basic_index' do
    context 'should not return paperwork_packets' do
      it "should return unauthorised status for unauthenticated user" do
        allow(controller).to receive(:current_user).and_return(nil)
        get :smart_packet_basic_index, format: :json
        expect(response.status).to eq(401)
      end

      it 'should return forbidden status if current_company is nil' do
        allow(controller).to receive(:current_company).and_return(nil)
        get :smart_packet_basic_index, format: :json
        expect(response.status).to eq(404)
      end

      it 'should return status if company available' do
        get :smart_packet_basic_index, params: {skip_pagination: true }, format: :json
        expect(response.status).to eq(200)
      end

    end
  end

end