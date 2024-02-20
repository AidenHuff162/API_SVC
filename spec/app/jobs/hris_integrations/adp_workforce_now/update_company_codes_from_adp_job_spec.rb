require 'rails_helper'

RSpec.describe HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob, type: :job do

  let!(:integration) { create(:adp_wfn_us_integration)}
  before {allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateCompanyCodesFromAdp).to receive(:sync) {'Service Executed'} }

  it 'should execute service to update company_codes' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob.new.perform(integration.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service to update company_codes if integration have enable_company_code as false' do
    integration.integration_credentials.find_by(name: 'Enable Company Code').update(value: false)
    result = HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob.new.perform(integration.id)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service to update company_codes if integration is not present' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateCompanyCodesFromAdpJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

end
