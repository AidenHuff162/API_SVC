require 'rails_helper'

RSpec.describe Okta::UpdateEmployeeInOktaJob, type: :job do

  let(:company) { create(:company) }
  let!(:integration) { create(:okta_integration_instance, company: company ) }
  let(:user) { create(:user, company: company, okta_id: 'id') }

  before do
    Net::HTTP.stub(:start) { double('okta', body: {"id": 'okta_id'}.to_json)}
  end
 
  it "should update employee in Okta " do
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to eq('okta_id')
  end

  it "should not update employee in Okta if user not present" do
    response = Okta::UpdateEmployeeInOktaJob.new.perform(nil)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not update employee in Okta if okta_id is not present" do
    user.update(okta_id: nil)
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not update employee in Okta if enable_update_profile is disabled" do
  	integration.integration_credentials.find_by(name: 'Enable Update Profile')&.update(value: false)
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not update employee in Okta if integration not present" do
  	integration.destroy
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not update employee in Okta if identity_provider_sso_url not present" do
    integration.integration_credentials.find_by(name: 'Identity Provider SSO Url')&.update(value: nil)
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end
end

