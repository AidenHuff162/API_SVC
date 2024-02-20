require 'rails_helper'

RSpec.describe PerformanceIntegrations::FifteenFive::DeleteFifteenFiveUserFromSaplingJob, type: :job do 
  let(:company) {create(:company)}
  let(:user) {create(:user, company: company, fifteen_five_id: 'id')}
  let!(:fifteen_five) { create(:fifteen_five_integration, company: company) }
  
  before do 
    allow_any_instance_of(PerformanceManagementIntegrationsService::FifteenFive::ManageSaplingProfileInFifteenFive).to receive(:perform) { 'Service Executed' }
    allow_any_instance_of(IntegrationInstance).to receive(:access_token).and_return('token')
    allow_any_instance_of(IntegrationInstance).to receive(:subdomain).and_return('subdomain')
    allow_any_instance_of(IntegrationInstance).to receive(:can_delete_profile).and_return(true) 
  end

  it 'should execute ManageSaplingProfileInFifteenFive' do
    res = PerformanceIntegrations::FifteenFive::DeleteFifteenFiveUserFromSaplingJob.new.perform(user)
    expect(res).to eq('Service Executed')
  end

  it 'should not execute ManageSaplingProfileInFifteenFive if fifteen_five_id not present' do
    user.update(fifteen_five_id: nil)
    res = PerformanceIntegrations::FifteenFive::DeleteFifteenFiveUserFromSaplingJob.new.perform(user)
    expect(res).to_not eq('Service Executed')
  end
end