require 'rails_helper'

RSpec.describe AdminUsers::DeactivateExpiredUsersJob, type: :job do
  before { allow_any_instance_of(Interactions::AdminUsers::DeactivateExpiredUsers).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = AdminUsers::DeactivateExpiredUsersJob.perform_now
    expect(res).to eq(true)
  end
end