require 'rails_helper'
RSpec.describe PeriodicJobs::CustomTable::ManageCustomTableUserSnapshots, type: :job do
  it 'should enque ManageCustomTableUserSnapshots job in sidekiq' do
  	snapshots_job_size = Sidekiq::Queues["default"].size
  	PeriodicJobs::CustomTable::ManageCustomTableUserSnapshots.new.perform
    expect(Sidekiq::Queues["default"].size).to eq(snapshots_job_size)
  end
end