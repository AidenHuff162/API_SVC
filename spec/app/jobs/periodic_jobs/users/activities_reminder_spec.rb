require 'rails_helper'
RSpec.describe PeriodicJobs::Users::ActivitiesReminder, type: :job do
  it 'should enque ActivitiesReminder job in sidekiq' do
    expect{ PeriodicJobs::Users::ActivitiesReminder.new.perform }.to have_enqueued_job(Users::ActivitiesReminderJob)
  end
end