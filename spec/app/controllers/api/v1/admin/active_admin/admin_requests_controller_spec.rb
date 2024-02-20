require 'rails_helper'

RSpec.describe Api::V1::Admin::ActiveAdmin::AdminRequestsController, type: :controller do


  let(:company) { create(:company, subdomain: 'tesla') }

  before do
    @admin_user = create(:admin_user, access_token: 'secret')
    sign_in @admin_user
    ActiveAdmin::SetEncryptedAccessToken.new(@admin_user.id).perform
    allow(controller).to receive(:current_admin_user).and_return(@admin_user)
  end

  describe 'load_company_team_and_locations' do

    context 'from unauthorised source' do

      it 'should return 401 response if access token is nil' do
        res = get :load_company_team_and_locations, params: { comp_id: company.id }
        expect(res.status).to eq(401)
      end

      it 'should return 401 response if access token is not correct' do
        res = get :load_company_team_and_locations, params: { comp_id: company.id, access_token: 'abc123' }
        expect(res.status).to eq(401)
      end

    end

    context 'with valid access token' do

      it 'should return a valid response' do
        res = get :load_company_team_and_locations, params: { comp_id: company.id, access_token: @admin_user.reload.access_token }
        expect(res.status).to eq(200)
      end

      it 'should referesh the access_token' do
        access_token = @admin_user.reload.access_token
        res = get :load_company_team_and_locations, params: { comp_id: company.id, access_token: @admin_user.reload.access_token }
        expect(access_token).to_not  eq(@admin_user.reload.access_token)
      end

    end

  end

end
