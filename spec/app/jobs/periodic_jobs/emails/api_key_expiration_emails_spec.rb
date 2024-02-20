require 'rails_helper'
RSpec.describe PeriodicJobs::Emails::ApiKeyExpirationEmails, type: :job do
  it 'should enque ApiKeyExpirationEmails job in sidekiq' do
    expect{ PeriodicJobs::Emails::ApiKeyExpirationEmails.new.perform }.to have_enqueued_job(ApiKeyExpirationEmailsJob)
  end
end