require 'rails_helper'
RSpec.describe PeriodicJobs::Integrations::Slack::SendIntegrationsApiErrorToSlack, type: :job do
  it 'should enque SendIntegrationsApiErrorToSlack job in sidekiq' do
    expect{ PeriodicJobs::Integrations::Slack::SendIntegrationsApiErrorToSlack.new.perform }.to have_enqueued_job(IntegrationErrors::SendIntegrationApiTestingErrorNotificationToSlackJob)
  end
end