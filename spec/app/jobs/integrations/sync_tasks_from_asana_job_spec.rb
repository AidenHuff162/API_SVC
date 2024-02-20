require 'rails_helper'

RSpec.describe Integrations::SyncTasksFromAsanaJob, type: :job do

  before do
    allow_any_instance_of(AsanaService::SyncTasks).to receive(:perform) {'Service Executed'}
  end
  it "should migrate the BswiftService " do
    response = Integrations::SyncTasksFromAsanaJob.new.perform
    expect(response).to eq('Service Executed')
  end
end

