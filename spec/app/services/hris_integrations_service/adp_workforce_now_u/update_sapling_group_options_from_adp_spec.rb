require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp do
  let(:company) { create(:company, subdomain: 'adp-template') }
  let(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }

  before(:all) do
    WebMock.disable_net_connect!
  end
  
  describe '#sync' do
    context 'credentials are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingGroupOptionsFromAdp - Access Token Retrieval - ERROR')
      end

      it 'should return 500 if certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingGroupOptionsFromAdp - Certificate Retrieval - ERROR')
      end
    end

    context 'credentials are valid' do
      before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end
      
      it 'should update sapling group options from ADP' do
        Sidekiq::Testing.inline! do
          response = double('body', :body => JSON.generate({'codeLists'=>[{'listItems'=>[{'shortName'=>'test','codeValue'=>'value'}]}]}), :reason_phrase => 'OK', :status => 200)
          allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)

          ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(adp_us).sync
          expect(company.locations.last.adp_wfn_us_code_value).to eq('value')
          expect(company.teams.last.adp_wfn_us_code_value).to eq("{\"default\":\"value\"}")

          business_unit = company.custom_fields.find_by(name: "Business Unit")
          expect(business_unit.custom_field_options.last.adp_wfn_us_code_value).to eq('value')
        end
      end

      it 'should return 404 if no group options found' do
        response = double('body', :body => '', :reason_phrase => '', :status => 404)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('UpdateSaplingGroupOptionsFromAdp - Job Titles - ERROR')
      end    

      it 'should return 500 if there is some exception' do
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingGroupOptionsFromAdp - Job Titles - ERROR')
      end 
    end
  end
end
