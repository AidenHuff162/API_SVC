require 'rails_helper'

RSpec.describe PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob, type: :job do 
  let(:company) {create(:company)}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::Lattice::ManageLatticeProfileInSapling).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(Company).to receive(:pm_integration_type) { 'fifteen_five'} 
  end

  it 'should execute ManageLatticeProfileInSapling' do
    res = PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob.new.perform(company.id)
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageLatticeProfileInSapling if company not present' do
    res = PerformanceIntegrations::Lattice::UpdateSaplingUserFromLatticeJob.new.perform(nil)
    expect(res).to_not eq('Service Executed')
  end
end