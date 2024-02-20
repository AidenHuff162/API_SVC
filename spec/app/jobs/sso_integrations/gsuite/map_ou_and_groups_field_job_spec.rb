require 'rails_helper'

RSpec.describe SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob, type: :job do
  let(:company) {create(:company)} 
  before do 
    allow_any_instance_of(Company).to receive(:get_gsuite_account_info) { true }
    allow_any_instance_of(::Gsuite::ManageAccount).to receive(:get_gsuite_ou) {'Service Executed'}
    allow_any_instance_of(::Gsuite::ManageAccount).to receive(:get_gsuite_groups) {'Service Executed'}
  end

  it 'should run service ManageAccount' do
    res = SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob.new.perform(company.id)
    expect(res).to eq('Service Executed')
  end

  it 'should not run service ManageAccount it company not present' do
    res = SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob.new.perform(nil)
    expect(res).to_not eq('Service Executed')
  end

  it 'should not run service ManageAccount it get_gsuite_account_info is not present' do
    allow_any_instance_of(Company).to receive(:get_gsuite_account_info) { nil }
    res = SsoIntegrations::Gsuite::MapOuAndGroupsFieldJob.new.perform(company.id)
    expect(res).to_not eq('Service Executed')
  end
end