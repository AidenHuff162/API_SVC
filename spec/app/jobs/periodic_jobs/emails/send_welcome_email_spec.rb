require 'rails_helper'
RSpec.describe PeriodicJobs::Emails::SendWelcomeEmail, type: :job do
  it 'should enque SendWelcomeEmail job in sidekiq' do
    expect{ PeriodicJobs::Emails::SendWelcomeEmail.new.perform }.to have_enqueued_job(Users::SendWelcomeEmailJob)
  end
end