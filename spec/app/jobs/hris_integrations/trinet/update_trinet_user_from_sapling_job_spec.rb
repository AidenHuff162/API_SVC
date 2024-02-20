require 'rails_helper'

RSpec.describe HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob , type: :job do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company, trinet_id: 'ss') }
  before do
  	allow_any_instance_of(::HrisIntegrationsService::Trinet::ManageSaplingProfileInTrinet).to receive(:perform) {'Service Executed'}  
  end

  it 'should execute service CreateTrinetUserFromSaplingJob From Sapling Job' do
    result = HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.new.perform({'user_id'=> user.id, 'attributes'=> 'attribute'})
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service CreateTrinetUserFromSaplingJob From Sapling Job if user not present' do
    result = HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.new.perform({'user_id'=> nil, 'attributes'=> 'attribute'})
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service CreateTrinetUserFromSaplingJob From Sapling Job if trinet_id not present' do
    user.update(trinet_id: nil)
    result = HrisIntegrations::Trinet::UpdateTrinetUserFromSaplingJob.new.perform({'user_id'=> nil, 'attributes'=> 'attribute'})
    expect(result).to_not eq('Service Executed')
  end
end
