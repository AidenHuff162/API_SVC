require 'rails_helper'

RSpec.describe SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob, type: :job do
  let(:company) {create(:company)}
  let(:user) {create(:user, active_directory_object_id: 'id')}
  before do 
    allow_any_instance_of(Company).to receive(:can_provision_adfs?) { true }
    allow_any_instance_of(::SsoIntegrationsService::ActiveDirectory::ManageSaplingProfileInActiveDirectory).to receive(:perform) {'Service Executed'}
  end

  it 'should run service ManageSaplingProfileInActiveDirectory' do
    res = SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.new.perform(user.id, 'attribute')
    expect(res).to eq('Service Executed')
  end

  it 'should not run service ManageSaplingProfileInActiveDirectory it user not present' do
    res = SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.new.perform(nil, 'attribute')
    expect(res).to_not eq('Service Executed')
  end

  it 'should not run service ManageSaplingProfileInActiveDirectory it active_directory_object_id is present' do
  	user.update(active_directory_object_id: nil)
    res = SsoIntegrations::ActiveDirectory::UpdateActiveDirectoryUserFromSaplingJob.new.perform(user.id, 'attribute')
    expect(res).to_not eq('Service Executed')
  end
end