require 'rails_helper'

RSpec.describe HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ManageCustomField do
  let(:company) { create(:company) }
  let(:adp_us) { create(:adp_integration, api_name: 'adp_wfn_us', company: company, meta: {location_id: ['all'], team_id: ['all'], employee_type: ['all'] }) }
  let(:user) { create(:user, state: :active, current_stage: :registered, company: company, adp_wfn_us_id: '123') } 

  before(:all) do
    WebMock.disable_net_connect!
  end

  describe '#update_adp_from_sapling' do
    it 'should update ADP from Sapling' do
      data_builder = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder.new('US')
      param_builder = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder.new
      stub_request(:post, 'https://api.adp.com/events/hr/v1/worker.custom-field.string.change').
      with(
        body: "{\"events\":[{\"eventNameCode\":{\"codeValue\":\"worker.customField.string.change\"},\"data\":{\"eventContext\":{\"worker\":{\"associateOID\":\"123\",\"customFieldGroup\":{\"stringField\":{\"itemID\":\"9200011471718_2040\"}}}},\"transform\":{\"worker\":{\"customFieldGroup\":{\"stringField\":{\"nameCode\":{\"shortName\":\"Personal Pronoun\"},\"stringValue\":\"\"}}}}}}]}",
        headers: {
        'Accept'=>'*/*',
        'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
        'Authorization'=>'Bearer test',
        'Content-Type'=>'application/json',
        'User-Agent'=>'Faraday v0.17.6'
        }).to_return(status: 200, body: JSON.generate({'a'=>'b'}), headers: {})

      ::HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ManageCustomField.new(company, user, adp_us, 'US', param_builder, data_builder, OpenStruct.new({cert: 'cert', key: 'key'}), 'test').update_adp_from_sapling('personal pronoun', nil, 'test')
      logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
      expect(logging.state).to eq(200)
      expect(logging.action).to eq('Update Profile in ADP - PERSONAL PRONOUN - SUCCESS')
    end

    it 'should not update ADP from Sapling' do
      data_builder = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::DataBuilder.new('US')
      param_builder = HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ParamsBuilder.new
      ::HrisIntegrationsService::AdpWorkforceNowU::WarbyParker::ManageCustomField.new(company, user, adp_us, 'US', param_builder, data_builder, OpenStruct.new({cert: 'cert', key: 'key'}), 'test').update_adp_from_sapling('personal pronoun', nil, 'test')
      logging = company.loggings.where(integration_name: 'ADP Workforce Now - US').last
      expect(logging.state).to eq(500)
      expect(logging.action).to eq('Update Profile in ADP - PERSONAL PRONOUN - ERROR')
    end
  end
end 