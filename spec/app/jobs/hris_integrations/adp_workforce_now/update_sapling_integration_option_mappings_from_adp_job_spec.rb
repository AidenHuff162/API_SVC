require 'rails_helper'

RSpec.describe HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob, type: :job do

  let!(:integration) { create(:adp_wfn_us_integration)}
  before do
  	allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingGroupOptionsFromAdp).to receive(:sync) {'Service Executed'} 
  	allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::UpdateSaplingCustomFieldOptionsFromAdp).to receive(:sync) {'Service Executed'} 
  end

  it 'should execute service to update imtegration mapping option' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob.new.perform(integration.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service to update imtegration mapping option if integration is not present' do
    result = HrisIntegrations::AdpWorkforceNow::UpdateSaplingIntegrationOptionMappingsFromAdpJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end

end
