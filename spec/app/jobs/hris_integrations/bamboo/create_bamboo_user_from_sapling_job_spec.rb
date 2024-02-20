require 'rails_helper'

RSpec.describe HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob , type: :job do
  let(:company) { create(:company, subdomain: 'rocketship') }
  let(:user) {FactoryGirl.create(:user, company: company)}
  before { allow_any_instance_of(::HrisIntegrationsService::Bamboo::UpdateBambooFromSapling).to receive(:create) {'Service Executed'}  }

  it 'should execute service Create Bamboo User From Sapling Job' do
    result = HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob.new.perform(user, true)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service Create Bamboo User From Sapling Job if user not present' do
    result = HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob.new.perform(nil, true)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service Create Bamboo User From Sapling Job if user is super_user' do
  	user.update(super_user: true)
    result = HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob.new.perform(nil, true)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service Create Bamboo User From Sapling Job if bamboo_id is present' do
  	user.update(bamboo_id: 'dqeq')
    result = HrisIntegrations::Bamboo::CreateBambooUserFromSaplingJob.new.perform(nil, true)
    expect(result).to_not eq('Service Executed')
  end
end
