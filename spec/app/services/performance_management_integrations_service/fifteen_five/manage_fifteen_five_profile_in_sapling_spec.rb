require 'rails_helper'

RSpec.describe PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive do
  let(:company) { create(:company, subdomain: 'fifteenfive-sapling-company') }
  let(:company2) { create(:company, subdomain: 'fifteenfive-sapling-company-2') }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company) } 
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company) }
  
  describe '#perform' do
     context 'integration is invalid' do
      it 'should return 404 if integration is invalid' do
        invalid_fifteen_five = FactoryGirl.create(:fifteen_five_integration, company: company2)
        PerformanceManagementIntegrationsService::FifteenFive::ManageFifteenFiveProfileInSapling.new(company2).perform
        logging = company2.loggings.where(integration_name: 'Fifteen Five').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq("Fifteen Five credentials missing - Update from 15five")
      end
      
      context 'integration is invalid' do
        before(:each) do
          WebMock.disable_net_connect!
          @fifteen_five = FactoryGirl.create(:fifteen_five_integration, company: company)
          allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('token')
          allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('test.staging')
          allow_any_instance_of(IntegrationInstance).to receive(:can_delete_profile).and_return(true)
        end

        it 'should map profile if user is present' do
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://#{@fifteen_five.subdomain}.15five.com/scim/v2/Users?startIndex=1&count=100").
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::FifteenFive::ManageFifteenFiveProfileInSapling.new(company).perform
          expect(user.reload.fifteen_five_id).to eq('12')
        end

        it 'should mot map profile if user is not present' do
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "123#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://#{@fifteen_five.subdomain}.15five.com/scim/v2/Users?startIndex=1&count=100").
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::FifteenFive::ManageFifteenFiveProfileInSapling.new(company).perform
          expect(user.reload.fifteen_five_id).to eq(nil)
        end

        it 'should mot map profile if two users has same profile' do
          user2.update_column(:personal_email, user.email)
          @response = JSON.generate({'Resources': [{'id': 12, 'emails': [{'value': "#{user.email}", 'primary': true}]}]})
          stub_request(:get, "https://#{@fifteen_five.subdomain}.15five.com/scim/v2/Users?startIndex=1&count=100").
              to_return(status: 200, body: @response)
          PerformanceManagementIntegrationsService::FifteenFive::ManageFifteenFiveProfileInSapling.new(company).perform
          expect(user.reload.fifteen_five_id).to eq(nil)
        end
      end
    end
  end
end
