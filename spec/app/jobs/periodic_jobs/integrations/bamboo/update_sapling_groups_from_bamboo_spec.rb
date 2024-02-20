require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Bamboo::UpdateSaplingGroupsFromBamboo, type: :job do

	let!(:company) { create(:with_bamboo_integration) }
	
  it 'should enque UpdateSaplingGroupsFromBamboo job in sidekiq' do
    expect{ PeriodicJobs::Integrations::Bamboo::UpdateSaplingGroupsFromBamboo.new.perform }.to have_enqueued_job(HrisIntegrations::Bamboo::UpdateSaplingGroupsFromBambooJob)
  end
end