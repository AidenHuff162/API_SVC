require 'rails_helper'

RSpec.describe PerformanceIntegrations::Peakon::CreatePeakonUserFromSaplingJob, type: :job do 
  let(:company) {create(:company)}
  let(:user) {create(:user, company: company)}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(Company).to receive(:pm_integration_type) { 'peakon'} 
  end

  it 'should execute ManageSaplingProfileInFifteenFive' do
    res = PerformanceIntegrations::Peakon::CreatePeakonUserFromSaplingJob.new.perform(user.id)
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageSaplingProfileInFifteenFive if peakon_id is present' do
    user.update(peakon_id: 'id')
    res = PerformanceIntegrations::Peakon::CreatePeakonUserFromSaplingJob.new.perform(user.id)
    expect(res).to_not eq('Service Executed')
  end
end