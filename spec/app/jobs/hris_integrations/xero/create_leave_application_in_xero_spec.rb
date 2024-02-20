require 'rails_helper'

RSpec.describe HrisIntegrations::Xero::CreateLeaveApplicationInXero , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let(:xero_integration_inventory) {create(:integration_inventory, display_name: 'Xero', status: 2, category: 0, data_direction: 1, enable_filters: false, api_identifier: 'xero')}
  let(:xero) {create(:integration_instance, api_identifier: 'xero', state: 'active', integration_inventory_id: xero_integration_inventory.id, name: 'Instance no.1', company_id: company.id)}
  let!(:nick) {FactoryGirl.create(:user_with_manager_and_policy, start_date: company.time.to_date - 2.year, company: company, xero_id: 'adfa')}
  subject(:pto_request) { create(:default_pto_request, user_id: nick.id, pto_policy_id: nick.pto_policies.first.id) }
  
  before do
    User.current = nick
    @pto_policy = nick.pto_policies.first
    @pto_policy.update(xero_leave_type_id: 'ssd')
    allow_any_instance_of(Company).to receive(:integration_type) { 'xero'}
    allow_any_instance_of(::HrisIntegrationsService::Xero::CreateLeaveApplicationsInXero).to receive(:create_leave_application) {'Service Executed'}  
  end
 
  it 'should execute service CreateLeaveApplicationsInXero' do
    xero.stub(:api_identifier) {'xero'}
    result = HrisIntegrations::Xero::CreateLeaveApplicationInXero.new.perform(pto_request.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service CreateLeaveApplicationsInXero if xero_id not present' do
    nick.update(xero_id: nil)
    result = HrisIntegrations::Xero::CreateLeaveApplicationInXero.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service CreateLeaveApplicationsInXero if leave id is not present' do
    @pto_policy.update(xero_leave_type_id: nil)
    result = HrisIntegrations::Xero::CreateLeaveApplicationInXero.new.perform(pto_request.id)
    expect(result).to_not eq('Service Executed')
  end
end
