require 'rails_helper'

RSpec.describe HrisIntegrations::Bamboo::CreateBambooJobTitleFromSaplingJob , type: :job do
  let(:company) { create(:company, subdomain: 'rocketship') }
  before { allow_any_instance_of(HrisIntegrationsService::Bamboo::JobTitle).to receive(:create) {'Service Executed'}  }

  it 'should execute service Create Bamboo Job Title From Sapling Job' do
    result = HrisIntegrations::Bamboo::CreateBambooJobTitleFromSaplingJob.new.perform(company, 'title')
    expect(result).to eq('Service Executed')
  end
end
