require 'rails_helper'

RSpec.describe HrisIntegrations::Trinet::CreateTrinetUserFromSaplingJob , type: :job do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  before do
  	allow_any_instance_of(::HrisIntegrationsService::Trinet::ManageSaplingProfileInTrinet).to receive(:perform) {'Service Executed'}  
  end

  it 'should execute service CreateTrinetUserFromSaplingJob From Sapling Job' do
    result = HrisIntegrations::Trinet::CreateTrinetUserFromSaplingJob.new.perform(user.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service CreateTrinetUserFromSaplingJob From Sapling Job if user not present' do
    result = HrisIntegrations::Trinet::CreateTrinetUserFromSaplingJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end
end
