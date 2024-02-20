require 'rails_helper'

RSpec.describe ActivitiesAssignedEmailJob, type: :job do 

  before { allow_any_instance_of(Interactions::Activities::Assign).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = ActivitiesAssignedEmailJob.perform_now(nil)
    expect(res).to eq(true)
  end
end