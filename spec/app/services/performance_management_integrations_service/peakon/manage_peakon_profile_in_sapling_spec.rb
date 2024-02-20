require 'rails_helper'

RSpec.describe PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling do
  let(:company) { create(:company, subdomain: 'peakon-sapling-company') }
  let(:company2) { create(:company, subdomain: 'peakon-sapling-company-2') }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }
  
  describe '#perform' do
     context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        invalid_peakon = FactoryGirl.create(:peakon_integration, company: company2)
        PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling.new(company2).perform
        logging = company2.loggings.where(integration_name: 'Peakon').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Peakon credentials missing - Update from Peakon")
      end
      
      context 'integration is invalid' do
        before(:each) do
          WebMock.disable_net_connect!
          @peakon = FactoryGirl.create(:peakon_integration, company: company)
          allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('token')
        end

        it 'should map profile if user is present' do
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://api.peakon.com/scim/v2/Users?startIndex=1&count=100").
              with(
                headers: {
                'Accept'=>'application/scim+json',
                'Authorization'=>"Bearer #{@peakon.access_token}"
              }).
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling.new(company).perform
          expect(user.reload.peakon_id).to eq('12')
        end

        it 'should mot map profile if user is not present' do
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "123#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://api.peakon.com/scim/v2/Users?startIndex=1&count=100").
              with(
                headers: {
                'Accept'=>'application/scim+json',
                'Authorization'=>"Bearer #{@peakon.access_token}"
              }).
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling.new(company).perform
          expect(user.reload.peakon_id).to eq(nil)
        end

        it 'should mot map profile if two users has same profile' do
          user2.update_column(:personal_email, user.email)
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://api.peakon.com/scim/v2/Users?startIndex=1&count=100").
              with(
                headers: {
                'Accept'=>'application/scim+json',
                'Authorization'=>"Bearer #{@peakon.access_token}"
              }).
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::Peakon::ManagePeakonProfileInSapling.new(company).perform
          expect(user.reload.peakon_id).to eq(nil)
        end
      end
    end
  end
end
