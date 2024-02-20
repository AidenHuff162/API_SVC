require 'rails_helper'

RSpec.describe Activities::ScheduleTasksJob, type: :job do
  before { allow_any_instance_of(Interactions::Activities::ScheduleTasks).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = Activities::ScheduleTasksJob.perform_now
    expect(res).to eq(true)
  end
end