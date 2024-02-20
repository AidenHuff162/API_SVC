require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp do
  let(:company) { create(:company, subdomain: 'adp-company-code') }
  let(:adp_us) { create(:adp_wfn_us_integration, company: company, filters: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }

  before(:all) do
    WebMock.disable_net_connect!
  end
  
  describe '#sync' do
    context 'credentials are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR')
      end

      it 'should return 500 if certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR')
      end
    end

    context 'credentials are valid' do
      before(:each) do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end
      
      it 'should sync company codes and save in Sapling' do
        adp_company_code = FactoryGirl.create(:custom_field, name: 'Adp Company Code', company: company, field_type: 4) 
        response = double('body', :body => JSON.generate({'meta'=>{'/data/transforms'=>[{'/jobOffer/offerAssignment/payrollGroupCode'=>{'codeList'=>{'listItems'=>[{'codeValue'=>'123'}]}}}]}}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(adp_us).sync
        expect(adp_company_code.reload.custom_field_options.count).to eq(1)
      end

      it 'should return 404 if no codes found' do
        response = double('body', :body => '', :reason_phrase => '', :status => 404)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('UpdateCompanyCodesFromAdp US - IntegrationMetadata - ERROR')
      end    

      it 'should return 500 if there is some exception' do
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateCompanyCodesFromAdp US - ERROR')
      end 
    end
  end
end
