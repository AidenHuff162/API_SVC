require 'rails_helper'
RSpec.describe PeriodicJobs::AdminUsers::DeactivateExpiredUsers, type: :job do
  it 'should enque DeactivateExpiredUsers job in sidekiq' do
    expect{ PeriodicJobs::AdminUsers::DeactivateExpiredUsers.new.perform }.to have_enqueued_job(AdminUsers::DeactivateExpiredUsersJob)
  end
end