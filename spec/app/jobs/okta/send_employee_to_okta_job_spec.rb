require 'rails_helper'

RSpec.describe Okta::SendEmployeeToOktaJob, type: :job do

  let(:company) { create(:company) }
  let!(:integration) { create(:okta_integration_instance, company: company ) }
  let(:user) { create(:user, company: company) }

  before do
    Net::HTTP.stub(:start) { double('okta', body: {"id": 'okta_id'}.to_json)}
  end
 
  it "should send employee the Okta " do
    response = Okta::SendEmployeeToOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to eq('okta_id')
  end

  it "should not send employee the Okta if user not present" do
    response = Okta::SendEmployeeToOktaJob.new.perform(nil)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not send employee the Okta if okta_id is present" do
    user.update(okta_id: 'id')
    response = Okta::SendEmployeeToOktaJob.new.perform(nil)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not send employee the Okta if enable_create_profile is disabled" do
  	integration.integration_credentials.find_by(name: 'Enable Create Profile')&.update(value: false)
    response = Okta::SendEmployeeToOktaJob.new.perform(nil)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not send employee the Okta if integration not present" do
  	integration.destroy
    response = Okta::SendEmployeeToOktaJob.new.perform(nil)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end

  it "should not send employee to Okta if identity_provider_sso_url not present" do
    integration.integration_credentials.find_by(name: 'Identity Provider SSO Url')&.update(value: nil)
    response = Okta::UpdateEmployeeInOktaJob.new.perform(user.id)
    expect(user.reload.okta_id).to_not eq('okta_id')
  end
end

