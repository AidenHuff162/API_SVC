require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling do
  let!(:company) { create(:company, subdomain: 'adp-sapling-company') }
  let(:location) { create(:location, company: company) }
  let!(:adp_us) { create(:adp_wfn_us_integration, company: company) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, location: location) } 

  let(:company2) { create(:company, subdomain: 'adp-sapling-company-2') }
  let!(:adp_can) { create(:adp_wfn_can_integration, company: company2) }
  let(:user2) { create(:user, state: :active, current_stage: :registered, company: company2) } 

  let(:company3) { create(:company, subdomain: 'adp-sapling-company-3') }
  let!(:adp_can_1) { create(:adp_wfn_can_integration, company: company3, filters: {"location_id"=>[""], "team_id"=>[""], "employee_type"=>["all"]}) }
  let!(:adp_us_1) { create(:adp_wfn_us_integration, company: company3, filters: {"location_id"=>[""], "team_id"=>["all"], "employee_type"=>["all"]}) }
  let(:user3) { create(:user, state: :active, current_stage: :registered, company: company3) } 
  let!(:api_logging) { create(:api_logging, api_key: 'ADP-US', company: company, status: 500, message: 'Invalid Request' ) }
  
  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#update' do
    context 'update_by_enviornment' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Helper).to receive(:notify_slack).and_wrap_original { |m, *args| api_logging }
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company).update
        logging = company.api_loggings.where(api_key: 'ADP-US').last
        expect(logging.status).to eq('500')
        expect(logging.message).to eq('Invalid Request')
      end

      it 'should return 500 if Certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Helper).to receive(:notify_slack).and_wrap_original { |m, *args| api_logging }
        ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company).update
        logging = company.api_loggings.where(api_key: 'ADP-US').last
        expect(logging.status).to eq('500')
        expect(logging.message).to eq('Invalid Request')
      end

      context 'credentials are valid' do
        before(:each) do
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
        end

        it 'should update profile in Sapling for ADP US' do
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)

          stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
            with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
            to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>user.email}]}}}]}))
          
          ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company).update
          expect(user.reload.adp_wfn_us_id).to eq('123')
        end

        it 'should create mismatched email logging in Sapling for ADP US' do
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)

          stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
            with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
            to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>'test@test.com'}]}}}]}))
          
          ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company).update
          logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').order(created_at: :desc).first
          expect(logging.state).to eq(200)
          expect(logging.action).to eq('ADP-IDs updates - Mismatched emails')
        end

        it 'should create profile for ADP CAN' do
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)

          stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
            with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
            to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>user2.email}]}}}]}))
          ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company2).update
          expect(user2.reload.adp_wfn_can_id).to eq('123')
        end
        
        context 'update_by_company_integration_type' do
          it 'should create profile for ADP US' do
            allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)

            stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
             with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
              to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>user.email}]}}}]}))

            ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company, 'adp_wfn_us').update
            expect(user.reload.adp_wfn_us_id).to eq('123')
          end

          it 'should create profile for ADP can' do
            allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)

            stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
              with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
              to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>user2.email}]}}}]}))

            ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company2, 'adp_wfn_can').update
            expect(user2.reload.adp_wfn_can_id).to eq('123')
          end
          
          it 'should create profile for ADP US and CAN' do
            allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateAdpProfileInSapling).to receive(:fetch_updates).and_return(true)
            adp_can_1.reload
            adp_us_1.reload
            stub_request(:get, "https://api.adp.com/hr/v2/workers?$skip=0&$top=100").
              with(
              headers: {
              'Accept'=>'*/*',
              'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
              'Authorization'=>'Bearer token',
              'Content-Type'=>'application/json',
              'User-Agent'=>'Ruby'
              }).
              to_return(status: 200, body: JSON.generate({'workers'=>[{'associateOID'=>'123','person'=>{'communication'=>{'emails'=>[{'emailUri'=>user3.email}]}}}]}))
            ::HrisIntegrationsService::AdpWorkforceNowU::ManageAdpProfileInSapling.new(company3).update
            expect(user3.reload.adp_wfn_us_id).to eq('123')
            expect(user3.reload.adp_wfn_can_id).to eq('123')
          end
        end
      end
    end
  end
end