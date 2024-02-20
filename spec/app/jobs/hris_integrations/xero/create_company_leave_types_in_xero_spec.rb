require 'rails_helper'

RSpec.describe HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero , type: :job do
  let(:company) { create(:company, enabled_time_off: true) }
  let!(:xero) {create(:xero_instance, company: company)}
  let!(:pto_policy) {create(:default_pto_policy, company: company)}

  it 'should enqueue job CreateLeaveTypesInXero' do
    expect{ HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero.new.perform(company.id) }.to change{HrisIntegrations::Xero::CreateLeaveTypesInXero.jobs.count}.by(1)
  end

  it 'should not enqueue CreateLeaveTypesInXero if company not present' do
    expect{HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero.new.perform(nil) }.to change{HrisIntegrations::Xero::CreateLeaveTypesInXero.jobs.count}.by(0)
  end

  it 'should not enqueue CreateLeaveTypesInXero if policy not present' do
    pto_policy.destroy
    expect{HrisIntegrations::Xero::CreateCompanyLeaveTypesInXero.new.perform(nil) }.to change{HrisIntegrations::Xero::CreateLeaveTypesInXero.jobs.count}.by(0)
  end

end
