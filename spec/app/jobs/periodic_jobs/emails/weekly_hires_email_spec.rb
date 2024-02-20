require 'rails_helper'
RSpec.describe PeriodicJobs::Emails::WeeklyHiresEmail, type: :job do
  it 'should enque WeeklyHiresEmail job in sidekiq' do
    expect{ PeriodicJobs::Emails::WeeklyHiresEmail.new.perform }.to have_enqueued_job(WeeklyHiresEmailJob)
  end
end