require 'rails_helper'

RSpec.describe Users::OffboardUserJob, type: :job do
  before { allow_any_instance_of(Interactions::Users::OffboardUser).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = Users::OffboardUserJob.perform_now
    expect(res).to eq(true)
  end
end