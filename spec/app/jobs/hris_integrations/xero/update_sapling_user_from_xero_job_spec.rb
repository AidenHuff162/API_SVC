require 'rails_helper'

RSpec.describe HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  before do
    allow_any_instance_of(Company).to receive(:integration_type) { 'xero'}
    allow_any_instance_of(::HrisIntegrationsService::Xero::ManageSaplingUserFromXero).to receive(:perform) {'Service Executed'}  
  end
 
  it 'should execute service ManageSaplingUserFromXero' do
    xero.stub(:api_identifier) {'xero'}
    result = HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob.new.perform(company.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service ManageSaplingUserFromXero if company not present' do
    result = HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service ManageSaplingUserFromXero if leave id is not present' do
    allow_any_instance_of(Company).to receive(:integration_type) { 'no'}
    result = HrisIntegrations::Xero::UpdateSaplingUserFromXeroJob.new.perform(company.id)
    expect(result).to_not eq('Service Executed')
  end
end
