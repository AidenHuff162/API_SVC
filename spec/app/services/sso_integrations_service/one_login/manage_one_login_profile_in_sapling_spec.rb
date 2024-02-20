require 'rails_helper'

RSpec.describe SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling do
  let(:company) { create(:company) }
  let(:company2) { create(:company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#perform' do
    context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        invalid_one_login = FactoryGirl.create(:one_login_integration_instance, company: company2)
        allow_any_instance_of(SsoIntegrationsService::OneLogin::Initializer).to receive(:fetch_access_token).and_return(false)
        SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling.new(company2).perform
        expect(company2.loggings.where(integration_name: 'OneLogin').last.api_request.include?("Onelogin credentials missing - Update from Onelogin")).to eq (true)
      end
    end

    context 'integration is valid' do
      before(:each) do
        allow_any_instance_of(SsoIntegrationsService::OneLogin::Initializer).to receive(:fetch_access_token).and_return('222')
        @one_login = FactoryGirl.create(:one_login_integration_instance, company: company)
      end

      it 'should map profile if user is present' do
        @response = JSON.generate({'data'=> [{'id'=> 12, 'email'=> "#{user.email}"}], 'pagination'=>{'after_cursor'=>nil}})
        stub_request(:get, "https://api.test.onelogin.com/api/1/users?after_cursor=").
          with(
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling.new(company).perform
        expect(user.reload.one_login_id).to eq(12)
      end

      it 'should mot map profile if user is not present' do
        @response = JSON.generate({'data'=> [{'id'=> 12, 'email'=> "123#{user.email}"}], 'pagination'=>{'after_cursor'=>nil}})
        stub_request(:get, "https://api.test.onelogin.com/api/1/users?after_cursor=").
          with(
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling.new(company).perform
        expect(user.reload.one_login_id).to eq(nil)
      end

      it 'should mot map profile if two users has same profile' do
        user2.update_column(:email, user.email)
        @response = JSON.generate({'data'=> [{'id'=> 12, 'email'=> "#{user.email}"}], 'pagination'=>{'after_cursor'=>nil}})
        stub_request(:get, "https://api.test.onelogin.com/api/1/users?after_cursor=").
          with(
          headers: {
          'Accept'=>'*/*',
          'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
          'Authorization'=>'bearer:222',
          'Content-Type'=>'application/json',
          'Host'=>'api.test.onelogin.com',
          'User-Agent'=>'Ruby'
          }).
          to_return(status: 200, body: @response)
        SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling.new(company).perform
        expect(user.reload.one_login_id).to eq(nil)
      end
    end
  end
end 