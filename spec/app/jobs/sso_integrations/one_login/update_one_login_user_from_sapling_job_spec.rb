require 'rails_helper'

RSpec.describe SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob, type: :job do 

  before { allow_any_instance_of(SsoIntegrationsService::OneLogin::ManageOneLoginFromSapling).to receive(:update_one_login_user).and_return(true)}

  it 'should run service and return true' do
    res = SsoIntegrations::OneLogin::UpdateOneLoginUserFromSaplingJob.new.perform(nil, nil)
    expect(res).to eq(true)
  end
end