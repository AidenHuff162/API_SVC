require 'rails_helper'

RSpec.describe PeriodicJobs::Pto::AutoCompletePtoRequest, type: :job do
  it 'should enque a job in sidekiq' do
    expect{ PeriodicJobs::Pto::AutoCompletePtoRequest.new.perform }.to have_enqueued_job(TimeOff::AutoCompletePtoRequestJob)
  end
end
