require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Namely::ReceiveEmployeesProfileImageFromNamely, type: :job do

	let!(:company) { create(:with_namely_integration) }
	
  it 'should enque PullEmployeesFromNamely job in sidekiq' do
    expect{ PeriodicJobs::Integrations::Namely::ReceiveEmployeesProfileImageFromNamely.new.perform }.to have_enqueued_job(UpdateSaplingDepartmentsAndLocationsFromNamelyJob)
  end
end