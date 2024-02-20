require 'rails_helper'
RSpec.describe PeriodicJobs::Reports::SendScheduledReports, type: :job do
  it 'should enque SendScheduledReports job in sidekiq' do
    expect{ PeriodicJobs::Reports::SendScheduledReports.new.perform }.to change{Sidekiq::Queues['report_schedule'].size }.by(1)
  end
end