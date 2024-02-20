require 'rails_helper'
RSpec.describe PeriodicJobs::Activities::ScheduleTasks, type: :job do
  it 'should enque ScheduleTasksJob job in sidekiq' do
    expect{ PeriodicJobs::Activities::ScheduleTasks.new.perform }.to have_enqueued_job(Activities::ScheduleTasksJob)
  end
end