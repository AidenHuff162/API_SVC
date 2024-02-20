require 'rails_helper'

RSpec.describe SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob, type: :job do
  let(:user) {create(:user)} 
  before do 
    allow_any_instance_of(::Gsuite::ManageAccount).to receive(:update_gsuite_account) {'Service Executed'}
  end

  it 'should run service ManageAccount' do
    res = SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.new.perform(user.id)
    expect(res).to eq('Service Executed')
  end

  it 'should not run service ManageAccount it user not present' do
    res = SsoIntegrations::Gsuite::UpdateGsuiteUserFromSaplingJob.new.perform(nil)
    expect(res).to_not eq('Service Executed')
  end
end