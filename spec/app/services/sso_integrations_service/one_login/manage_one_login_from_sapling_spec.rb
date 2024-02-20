require 'rails_helper'

RSpec.describe SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling do
  let(:company) { create(:company) }
  let(:one_login) { create(:one_login_integration_instance, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:update_user) { create(:user, state: :active, current_stage: :registered, company: company, one_login_id: '123') } 

  before(:all) do
    WebMock.disable_net_connect!
  end


  before(:each) do
    stub_request(:post, "https://api.test.onelogin.com/auth/oauth2/v2/token").
      with(
      body: "{\"grant_type\":\"client_credentials\"}",
      basic_auth: [one_login.client_id, one_login.client_secret],
      headers: {
      'Content-Type'=>'application/json'
       }).
      to_return(status: 200, body: JSON.generate({'access_token'=>'222'}))
  end

  describe '#create_one_login_user' do
    context 'Create Sapling Profile In one login' do
      before(:each) do
        @request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).create_params
        @request_params_custom = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).build_custom_attributes
        @response = JSON.generate({'data'=>[{'id'=>'123'}], 'status'=>{'code': 200}})
        company.stub(:authentication_type) {'one_login'}
      end

      it 'should create user in OneLogin' do
        stub_request(:post, "https://api.test.onelogin.com/api/1/users").
          with(
          body: JSON.generate(@request_params),
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        one_login_manager = ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(user.id)
        one_login_manager.stub(:create_one_login_user_custom_attributes) {'Updated custom attributes'}
        one_login_manager.create_one_login_user
        expect(user.reload.one_login_id).to eq(123)
      end

      it 'should reutrn 500 if there is some exception' do
        one_login_manager = ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(user.id)
        one_login_manager.stub(:create_one_login_user_custom_attributes) {'Updated custom attributes'}
        one_login_manager.create_one_login_user
        expect(user.reload.one_login_id).to eq(nil)
      end
    end
  end

  describe '#update_one_login_user' do
    context 'Update Sapling Profile In Onelogin' do
      before(:each) do
        @response = JSON.generate({'data'=>[{'id'=>'123'}], 'status'=>{'code': 200}})
      end

      it 'should update user in Onelogin' do
        request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(update_user, one_login).update_params('first_name', {})
        stub_request(:put, "https://api.test.onelogin.com/api/1/users/123").
         with(
           body: JSON.generate(request_params),
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['first_name'])
        expect(one_login.reload.synced_at).not_to eq (nil)
      end

      it 'should update mobile phone number in Onelogin' do
        request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(update_user, one_login).update_params('mobile phone number', {})
        stub_request(:put, "https://api.test.onelogin.com/api/1/users/123").
         with(
           body: JSON.generate(request_params),
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['mobile phone number'])
        expect(one_login.reload.synced_at).not_to eq (nil)
      end

      it 'should update start date in Onelogin' do
        request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(update_user, one_login).update_params('start_date', {})
        stub_request(:put, "https://api.test.onelogin.com/api/1/users/123").
         with(
           body: JSON.generate(request_params),
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['start_date'])
        expect(one_login.reload.synced_at).not_to eq (nil)
      end

      it 'should update team_id in Onelogin' do
        request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(update_user, one_login).update_params('team', {})
        stub_request(:put, "https://api.test.onelogin.com/api/1/users/123").
         with(
           body: JSON.generate(request_params),
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['team'])
        expect(one_login.reload.synced_at).not_to eq (nil)
      end

      it 'should reutrn 500 if there is some exception' do
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['first_name'])
        expect(one_login.reload.synced_at).to eq (nil)
      end
    end
  end

  describe '#update_one_login_user' do
    context 'update_one_login_user Profile In Onelogin' do
      before(:each) do
        @request_params = ::SsoIntegrationsService::OneLogin::BuildParams.new(update_user, one_login).update_params('first_name', {})
        @response = JSON.generate({'data'=>[{'id'=>'123'}], 'status'=> {'code': 200}})
      end

      it 'should update user in Onelogin' do
        stub_request(:put, "https://api.test.onelogin.com/api/1/users/123").
         with(
           body: JSON.generate(@request_params),
           headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
           }).
          to_return(status: 200, body: @response)

        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['first_name'])
        expect(one_login.reload.synced_at).not_to eq (nil)
      end

      it 'should reutrn 500 if there is some exception' do
        ::SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling.new(update_user.id).update_one_login_user(['first_name'])
        expect(one_login.reload.synced_at).to eq (nil)
      end
    end
  end

  describe '#create_one_login_user_with_sync_preferred_name' do
    context 'Create Sapling Profile In one login with sync_preferred_name' do

      it 'should include first_name as preferred_name' do
        one_login.integration_credentials.find_by(name: 'Sync Preferred Name')&.update(value: true)
        user.update(preferred_name: "Nich")
        data = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).create_params
        expect(data).to include(:firstname => "Nich")
      end

      it 'should not include first_name as preferred_name' do
        one_login.integration_credentials.find_by(name: 'Sync Preferred Name')&.update(value: false)
        data = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).create_params
        expect(data).not_to include(:firstname => "Nich")
      end
    end
  end

  describe '#update_one_login_user_with_sync_preferred_name' do
    context 'Update Sapling Profile In one login with sync_preferred_name' do

      it 'should include first_name as preferred_name' do
        one_login.integration_credentials.find_by(name: 'Sync Preferred Name')&.update(value: true)
        user.update(preferred_name: "Nich")
        data = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).update_params('preferred_name', {})
        expect(data).to include(:firstname => "Nich")
      end

      it 'should not include first_name as preferred_name' do
        one_login.integration_credentials.find_by(name: 'Sync Preferred Name')&.update(value: false)
        data = ::SsoIntegrationsService::OneLogin::BuildParams.new(user, one_login).update_params('preferred_name', {})
        expect(data).not_to include(:firstname => "Nich")
      end
    end
  end

end 