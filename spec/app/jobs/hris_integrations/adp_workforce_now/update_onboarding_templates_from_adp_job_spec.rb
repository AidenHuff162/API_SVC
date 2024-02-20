require 'rails_helper'

RSpec.describe HrisIntegrations::AdpWorkforceNow::UpdateOnboardingTemplatesFromAdpJob, type: :job do

  let!(:integration) { create(:adp_wfn_us_integration)}
  before {allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateOnboardingTemplatesFromAdp).to receive(:sync) {'Service Executed'} }

  it 'should execute service to update onaboarding templates' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateOnboardingTemplatesFromAdpJob.new.perform(integration.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service to update onaboarding templates if integration is not present' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateOnboardingTemplatesFromAdpJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

end
