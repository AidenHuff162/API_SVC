require 'rails_helper'
RSpec.describe PeriodicJobs::Users::OffboardUser, type: :job do
  it 'should enque OffboardUser job in sidekiq' do
    expect{ PeriodicJobs::Users::OffboardUser.new.perform }.to have_enqueued_job(Users::OffboardUserJob)
  end
end