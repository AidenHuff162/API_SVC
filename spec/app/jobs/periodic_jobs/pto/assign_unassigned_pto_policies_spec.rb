require 'rails_helper'

RSpec.describe PeriodicJobs::Pto::AssignUnassignedPtoPolicies, type: :job do
  it 'should enque a job in sidekiq' do
    expect{ PeriodicJobs::Pto::AssignUnassignedPtoPolicies.new.perform }.to have_enqueued_job(TimeOff::ActivateUnassignedPolicy)
  end
end
