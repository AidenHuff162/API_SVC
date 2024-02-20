require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp do
  let(:company) { create(:company, subdomain: 'adp-template') }
  let(:company2) { create(:company, subdomain: 'adp-can-template') }
  let(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }
  let(:adp_can) { create(:adp_wfn_can_integration, company: company2, filters: {location_id: [''], team_id: ['all'], employee_type: [''] }) }

  before(:all) do
    WebMock.disable_net_connect!
  end
  
  describe '#sync' do
    context 'credentials are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR')
      end

      it 'should return 500 if certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR')
      end
    end

    context 'credentials are valid' do
      before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return('certificate')
      end
      
      it 'should onboarding templates and save in Sapling for ADP US' do
        response = double('body', :body => JSON.generate({'codeLists'=>[{'listItems'=>[{'shortName'=>'HR + Payroll (System)', 'longName'=>'HR + Payroll (System)'}]}]}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_us).sync
        expect(adp_us.integration_credentials.find_by(name: 'Onboarding Templates').dropdown_options.count).to eq(1)
      end

      it 'should onboarding templates and save in Sapling for ADP CAN' do
        response = double('body', :body => JSON.generate({'codeLists'=>[{'listItems'=>[{'shortName'=>'HR + Payroll (System)', 'longName'=>'HR + Payroll (System)'}]}]}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_can).sync
        expect(adp_can.integration_credentials.find_by(name: 'Onboarding Templates').dropdown_options.count).to eq(1)
      end

      it 'should return 404 if no templates found' do
        response = double('body', :body => '', :reason_phrase => '', :status => 404)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)

        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('UpdateOnboardingTemplatesFromAdp US - IntegrationMetadata - ERROR')
      end    

      it 'should return 500 if there is some exception' do
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateOnboardingTemplatesFromAdp US - ERROR')
      end 
    end
  end
end
