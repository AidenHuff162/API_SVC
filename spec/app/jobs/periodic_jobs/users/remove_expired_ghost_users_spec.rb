require 'rails_helper'
RSpec.describe PeriodicJobs::Users::RemoveExpiredGhostUsers, type: :job do
  it 'should enque RemoveExpiredGhostUsers job in sidekiq' do
    expect{ PeriodicJobs::Users::RemoveExpiredGhostUsers.new.perform }.to have_enqueued_job(Users::RemoveExpiredGhostUsersJob)
  end
end