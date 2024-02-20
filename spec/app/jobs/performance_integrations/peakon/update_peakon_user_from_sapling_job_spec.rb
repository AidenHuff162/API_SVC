require 'rails_helper'

RSpec.describe PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob, type: :job do 
  let(:company) {create(:company)}
  let(:user) {create(:user, company: company, peakon_id: 'id')}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(Company).to receive(:pm_integration_type) { 'peakon'} 
  end

  it 'should execute ManageSaplingProfileInFifteenFive' do
    res = PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.new.perform({'user_id'=> user.id, 'attribute'=> 'attribute'})
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageSaplingProfileInFifteenFive if peakon_id is not present' do
    user.update(peakon_id: nil)
    res = PerformanceIntegrations::Peakon::UpdatePeakonUserFromSaplingJob.new.perform({'user_id'=> user.id, 'attribute' =>'attribute'})
    expect(res).to_not eq('Service Executed')
  end
end