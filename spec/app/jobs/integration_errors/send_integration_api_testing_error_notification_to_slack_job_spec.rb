require 'rails_helper'

RSpec.describe IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let!(:user) {create(:default_pto_policy, company: company)}
  let!(:slack_integration) {create(:slack_communication_integration_instance, company: company)}
  before do
    @synced_at = slack_integration.synced_at
    RestClient.stub(:post) {true}  
  end
  
  describe 'send error notification to Slack' do
    context 'namely integration' do
      # let!(:namely_integration) {create(:namely_integration, company: company)}
      # before do 
      #   Company.any_instance.stub(:integration_type) { 'namely'}
      #   Namely::Connection.any_instance.stub(:job_titles) { nil }
      # end
      
      # it 'should send error message to slack for access token' do
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end

      # it 'should send error message to slack for subdomain' do
      #   namely_integration.update(subdomain: nil, secret_token: 'token')
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end

      # it 'should send error message to slack for subdomain & token' do
      #   namely_integration.update(subdomain: nil)
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end

      # it 'should send error message to slack if integration not present' do
      #   namely_integration.destroy
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end

      # it 'should send error message to slack when trying to access namely with invalid credentials' do
      #   namely_integration.update(secret_token: 'token')
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end
    end

    context 'bamboo integration' do
      let!(:bamboo_integration) {create(:bamboohr_integration, company: company)}
      before do 
        allow_any_instance_of(Company).to receive(:integration_types) { ['bamboo_hr']}
      end
      
      it 'should send error message to slack for api key' do
        bamboo_integration.integration_credentials.find_by(name: 'Api Key').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for subdomain' do
        bamboo_integration.integration_credentials.find_by(name: 'Subdomain').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for subdomain & api key' do
        bamboo_integration.integration_credentials.find_by(name: 'Subdomain').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack if integration not present' do
        bamboo_integration.destroy
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should not send error message to slack when cedentials present' do
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to eq(nil)
      end
    end

    context 'adp_can integration' do
      let!(:adp_can_integration) {create(:adp_wfn_can_integration, company: company)}
      before do 
        allow_any_instance_of(Company).to receive(:integration_types) { ['adp_wfn_can']}
      end
      
      it 'should send error message to slack for client_secret' do
        adp_can_integration.integration_credentials.find_by(name: 'Client Secret').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for client_id' do
        adp_can_integration.integration_credentials.find_by(name: 'Client ID').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for client_id & client_secret' do
        adp_can_integration.integration_credentials.find_by(name: 'Client ID').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack if integration not present' do
        adp_can_integration.destroy
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      # it 'should  send error message to slack when accessing integration with invalid credentials' do
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end
    end

    context 'adp_canus integration' do
      let!(:adp_us_integration) {create(:adp_wfn_us_integration, company: company)}
      before do 
        allow_any_instance_of(Company).to receive(:integration_types) { ['adp_wfn_us']}
      end
      
      it 'should send error message to slack for client_secret' do
        adp_us_integration.integration_credentials.find_by(name: 'Client Secret').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for client_id' do
        adp_us_integration.integration_credentials.find_by(name: 'Client ID').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for client_id & client_secret' do
        adp_us_integration.integration_credentials.find_by(name: 'Client Secret').update(value: nil)
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack if integration not present' do
        adp_us_integration.destroy
        result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      # it 'should send error message to slack when accessing integration with invalid credentials' do
      #   result = IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
      #   expect(slack_integration.reload.synced_at).to_not eq(nil)
      # end
    end

    context 'multiple integration' do
      let!(:adp_can_integration) {create(:adp_wfn_can_integration, company: company)}
      let!(:bamboo_integration) {create(:bamboohr_integration, company: company)}
      let!(:adp_us_integration) {create(:adp_wfn_us_integration, company: company, filters: {location_id: [''], team_id: ['all'], employee_type: ['all']})}

      before do
        bamboo_integration.integration_credentials.find_by(name: 'Api Key').update(value: nil)
        adp_can_integration.integration_credentials.find_by(name: 'Client Secret').update(value: nil)
        adp_us_integration.integration_credentials.find_by(name: 'Client Secret').update(value: nil)
      end

      it 'should send error message to slack for client_secret for adp_wfn_profile_creation_and_bamboo_two_way_sync' do
        allow_any_instance_of(Company).to receive(:integration_types) { ['adp_wfn_us', 'bamboo_hr']}
        IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end

      it 'should send error message to slack for client_secret for adp_wfn_us_and_ca' do
        allow_any_instance_of(Company).to receive(:integration_types) { ['adp_wfn_us', 'adp_wfn_can']}
        IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob.new.perform
        expect(slack_integration.reload.synced_at).to_not eq(nil)
      end
    end
  end
end