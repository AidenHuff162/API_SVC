require 'rails_helper'

RSpec.describe HrisIntegrations::Xero::CreateLeaveTypesInXero , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let!(:pto_policy) {create(:default_pto_policy, company: company)}
  before do
    allow_any_instance_of(Company).to receive(:integration_type) { 'xero'}
    allow_any_instance_of(::HrisIntegrationsService::Xero::CreateLeaveTypesInXero).to receive(:create_leave_type) {'Service Executed'}  
  end
 
  it 'should execute service CreateLeaveTypesInXero' do
    xero.stub(:api_identifier) {'xero'}
    result = HrisIntegrations::Xero::CreateLeaveTypesInXero.new.perform(pto_policy.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service CreateLeaveTypesInXero if policy not present' do
    pto_policy.destroy
    result = HrisIntegrations::Xero::CreateLeaveTypesInXero.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service CreateLeaveTypesInXero if leave id is present' do
    pto_policy.update(xero_leave_type_id:'sd')
    result = HrisIntegrations::Xero::CreateLeaveTypesInXero.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end
end
