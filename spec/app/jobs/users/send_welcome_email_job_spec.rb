require 'rails_helper'

RSpec.describe Users::SendWelcomeEmailJob, type: :job do
  before { allow_any_instance_of(Interactions::Users::SendWelcomeEmail).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = Users::SendWelcomeEmailJob.perform_now
    expect(res).to eq(true)
  end
end