require 'rails_helper'

RSpec.describe HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob , type: :job do
  let(:company) { create(:company, subdomain: 'rocketship') }
  let(:user) {FactoryGirl.create(:user, company: company, bamboo_id: 'sas')}
 
  before { allow_any_instance_of(HrisIntegrationsService::Bamboo::UpdateBambooFromSapling).to receive(:update) {'Service Executed'}  }

  it 'should execute service UpdateBambooUserFromSaplingJob ' do
    result = HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.new.perform(user, 'field')
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service UpdateBambooUserFromSaplingJob for paperwork_request if user is super_user' do
    user.update(super_user: true)
    result = HrisIntegrations::Bamboo::UpdateBambooUserFromSaplingJob.new.perform(user, 'field')
    expect(result).to_not eq('Service Executed')
  end
end
