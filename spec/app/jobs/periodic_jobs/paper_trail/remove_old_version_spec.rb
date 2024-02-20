require 'rails_helper'
RSpec.describe PeriodicJobs::PaperTrail::RemoveOldVersion, type: :job do
  it 'should enque RemoveOldVersion job in sidekiq' do
    expect{ PeriodicJobs::PaperTrail::RemoveOldVersion.new.perform }.to have_enqueued_job(PaperTrail::RemoveOldVersionJob)
  end
end