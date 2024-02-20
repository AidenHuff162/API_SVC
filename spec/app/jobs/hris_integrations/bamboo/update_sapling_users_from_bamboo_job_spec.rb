require 'rails_helper'

RSpec.describe HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob , type: :job do
  let(:company) { create(:company, subdomain: 'rocketship') }
 
  before { allow_any_instance_of(HrisIntegrationsService::Bamboo::UpdateSaplingFromBamboo).to receive(:perform) {'Service Executed'}  }

  it 'should execute service UpdateSaplingFromBamboo ' do
    result = HrisIntegrations::Bamboo::UpdateSaplingUsersFromBambooJob.new.perform(company.id)
    expect(result).to eq('Service Executed')
  end
end
