require 'rails_helper'

RSpec.describe PerformanceIntegrations::FifteenFive::UpdateSaplingUserFromFifteenFiveJob, type: :job do 
  let(:company) {create(:company)}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::FifteenFive::ManageFifteenFiveProfileInSapling).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(Company).to receive(:pm_integration_type) { 'fifteen_five'} 
  end

  it 'should execute ManageFifteenFiveProfileInSapling' do
    res = PerformanceIntegrations::FifteenFive::UpdateSaplingUserFromFifteenFiveJob.new.perform(company.id)
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageFifteenFiveProfileInSapling if company not present' do
    res = PerformanceIntegrations::FifteenFive::UpdateSaplingUserFromFifteenFiveJob.new.perform(nil)
    expect(res).to_not eq('Service Executed')
  end
end
