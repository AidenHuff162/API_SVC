require 'rails_helper'
RSpec.describe PeriodicJobs::AddMonthlyActiveUsers, type: :job do
  it 'should enque AddMonthlyActiveUsers job in sidekiq' do
  	active_users_job_size = Sidekiq::Queues["default"].size
  	PeriodicJobs::AddMonthlyActiveUsers.new.perform
    expect(Sidekiq::Queues["default"].size).to eq(active_users_job_size + 1)
  end
end