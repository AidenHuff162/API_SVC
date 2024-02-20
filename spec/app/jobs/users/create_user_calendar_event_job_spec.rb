require 'rails_helper'

RSpec.describe Users::CreateUserCalendarEventJob, type: :job do
  before { allow_any_instance_of(Interactions::Users::CreateUserCalendarEvent).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = Users::CreateUserCalendarEventJob.perform_now
    expect(res).to eq(true)
  end
end