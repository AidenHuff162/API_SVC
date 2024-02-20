require 'rails_helper'

RSpec.describe Users::ActivitiesReminderJob, type: :job do
  before { allow_any_instance_of(Interactions::Users::ActivitiesReminder).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = Users::ActivitiesReminderJob.perform_now
    expect(res).to eq(true)
  end
end