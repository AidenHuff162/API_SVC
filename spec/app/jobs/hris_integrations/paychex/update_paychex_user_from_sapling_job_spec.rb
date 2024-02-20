require 'rails_helper'

RSpec.describe HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob , type: :job do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, paychex_id: 'd') }
  before do
  	allow_any_instance_of(Company).to receive(:integration_type) {'paychex'}
  	allow_any_instance_of(HrisIntegrationsService::Paychex::ManageSaplingProfileInPaychex).to receive(:perform) {'Service Executed'}  
  end

  it 'should execute service ManageSaplingProfileInPaychex From Sapling Job' do
    result = HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.new.perform(user.id, 'attribute')
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service ManageSaplingProfileInPaychex From Sapling Job if paychex id is present' do
  	user.update(paychex_id: nil)
    result = HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.new.perform(user.id, 'attribute')
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service ManageSaplingProfileInPaychex From Sapling Job if user not present' do
    result = HrisIntegrations::Paychex::UpdatePaychexUserFromSaplingJob.new.perform(nil, 'attribute')
    expect(result).to_not eq('Service Executed')
  end
end
