require 'rails_helper'

RSpec.describe SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob, type: :job do 
  let(:company) {create(:company)}
  before do 
    allow_any_instance_of(SsoIntegrationsService::OneLogin::ManageOneLoginProfileInSapling).to receive(:perform) { true }
    allow_any_instance_of(Company).to receive(:authentication_type) { 'one_login'} 
  end

  it 'should run service and return true' do
    res = SsoIntegrations::OneLogin::UpdateSaplingUserFromOneloginJob.new.perform(company.id)
    expect(res).to eq(true)
  end
end