require 'rails_helper'

RSpec.describe HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob , type: :job do
  let(:company) { create(:company ) }
  let(:user) { create(:user, company: company, deputy_id: 'ssd') }
  before do
  	allow_any_instance_of(HrisIntegrationsService::Deputy::ManageSaplingProfileInDeputy).to receive(:perform) {'Service Executed'}  
  end

  it 'should execute service ManageSaplingProfileInDeputy From Sapling Job' do
    result = HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob.new.perform(user.id)
    expect(result).to eq('Service Executed')
  end

  it 'should not execute service ManageSaplingProfileInDeputy From Sapling Job if deputy id is not present' do
  	user.update(deputy_id: nil)
    result = HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob.new.perform(user.id)
    expect(result).to_not eq('Service Executed')
  end

  it 'should not execute service ManageSaplingProfileInDeputy From Sapling Job if user not present' do
  	user.update(deputy_id: 'asd')
    result = HrisIntegrations::Deputy::RehireDeputyUserFromSaplingJob.new.perform(nil)
    expect(result).to_not eq('Service Executed')
  end
end
