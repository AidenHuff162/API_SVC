require 'rails_helper'

RSpec.describe PerformanceIntegrations::Peakon::DeletePeakonUserFromSaplingJob, type: :job do 
  let(:company) {create(:company)}
  let(:user) {create(:user, company: company, peakon_id: 'id')}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::Peakon::ManageSaplingProfileInPeakon).to receive(:perform) { 'Service Executed' }
  end

  it 'should execute ManageSaplingProfileInFifteenFive' do
    res = PerformanceIntegrations::Peakon::DeletePeakonUserFromSaplingJob.new.perform(user)
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageSaplingProfileInFifteenFive if peakon_id is not present' do
    user.update(peakon_id: nil)
    res = PerformanceIntegrations::Peakon::DeletePeakonUserFromSaplingJob.new.perform(user)
    expect(res).to_not eq('Service Executed')
  end
end