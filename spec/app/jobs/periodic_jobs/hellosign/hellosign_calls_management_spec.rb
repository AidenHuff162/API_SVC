require 'rails_helper'
RSpec.describe PeriodicJobs::Hellosign::HellosignCallsManagement, type: :job do
  it 'should enque HellosignCallsManagement job in sidekiq' do
  	hello_sign_job_size = Sidekiq::Queues["hellosign_call"].size
  	PeriodicJobs::Hellosign::HellosignCallsManagement.new.perform
    expect(Sidekiq::Queues["hellosign_call"].size).to eq(hello_sign_job_size + 1)
  end
end