require 'rails_helper'
RSpec.describe PeriodicJobs::Users::CreateUserCalendarEvent, type: :job do
  it 'should enque CreateUserCalendarEvent job in sidekiq' do
    expect{ PeriodicJobs::Users::CreateUserCalendarEvent.new.perform }.to have_enqueued_job(Users::CreateUserCalendarEventJob)
  end
end