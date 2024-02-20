require 'rails_helper'

RSpec.describe PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob, type: :job do 
  let(:company) {create(:company)}
  let(:user) {create(:user, company: company, fifteen_five_id: 'id')}
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(Company).to receive(:pm_integration_type) { 'fifteen_five'} 
  end

  it 'should execute ManageSaplingProfileInFifteenFive' do
    res = PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob.new.perform({'user_id'=>user.id})
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageSaplingProfileInFifteenFive if fifteen_five_id not present' do
    user.update(fifteen_five_id: nil)
    res = PerformanceIntegrations::FifteenFive::UpdateFifteenFiveUserFromSaplingJob.new.perform({'user_id'=>user.id})
    expect(res).to_not eq('Service Executed')
  end
end