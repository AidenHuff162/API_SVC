require 'rails_helper'
RSpec.describe PeriodicJobs::FixCounters, type: :job do
  it 'should enque FixCounters job in sidekiq' do
  	fix_counters_job_size = Sidekiq::Queues["fix_counter"].size
  	PeriodicJobs::FixCounters.new.perform
    expect(Sidekiq::Queues["fix_counter"].size).to eq(fix_counters_job_size + 1)
  end
end