require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp do
  let(:company) { create(:company, subdomain: 'adp-company-code') }
  let(:adp_us) { create(:adp_wfn_us_integration, company: company ) }
  let(:company2) { create(:company, subdomain: 'adp-can-template') }
  let(:adp_can) { create(:adp_wfn_can_integration, company: company2) }

  before(:all) do
    WebMock.disable_net_connect!
  end
  
  describe '#sync' do
    context 'credentials are invalid' do
      it 'should return 500 if access token is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Access Token Retrieval - ERROR')
      end

      it 'should return 500 if certificate is invalid' do
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_raise(Exception)
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingFieldOptionsFromAdp - Certificate Retrieval - ERROR')
      end
    end

    context 'credentials are valid' do
      before(:each) do
        @field = company.custom_fields.where(field_type: CustomField.field_types[:employment_status]).take
        @field2 = company2.custom_fields.where(field_type: CustomField.field_types[:employment_status]).take
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_access_token).and_return('token')
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Configuration).to receive(:retrieve_certificate).and_return(OpenStruct.new({cert: 'cert', key: 'key'}))
      end
      
      it 'should sync company codes and save in Sapling For ADP US' do
        response = double('body', :body => JSON.generate({'meta'=>{'/workers/workAssignments/workerTypeCode'=>{'codeList'=>{'listItems'=>[{'shortName'=>'short', 'codeValue'=>'value'}]}}}}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_us).sync
        expect(@field.custom_field_options.count).to eq(3)
        expect(@field.custom_field_options.find_by(option: 'short').adp_wfn_us_code_value).to eq('value')
      end

      it 'should sync company codes and save in Sapling For ADP Canada' do
        response = double('body', :body => JSON.generate({'meta'=>{'/workers/workAssignments/workerTypeCode'=>{'codeList'=>{'listItems'=>[{'shortName'=>'short', 'codeValue'=>'value'}]}}}}), :reason_phrase => 'OK', :status => 200)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_can).sync
        expect(@field2.custom_field_options.count).to eq(3)
        expect(@field2.custom_field_options.find_by(option: 'short').adp_wfn_can_code_value).to eq('value')
      end

      it 'should return 404 if no codes found' do
        response = double('body', :body => '', :reason_phrase => '', :status => 404)
        allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::Events).to receive(:get).and_return(response)
        
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(404)
        expect(logging.action).to eq('UpdateSaplingCustomFieldOptionsFromAdp - IntegrationMetadata - ERROR')
      end    

      it 'should return 500 if there is some exception' do
        ::HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp.new(adp_us).sync
        logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
        expect(logging.state).to eq(500)
        expect(logging.action).to eq('UpdateSaplingCustomFieldOptionsFromAdp IntegrationMetadata - ERROR')
      end 
    end
  end
end
