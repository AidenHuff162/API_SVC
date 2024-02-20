require 'rails_helper'

RSpec.describe SendUpdatedEmployeeToAdpWorkforceNowJob, type: :job do 
  let(:user) {create(:user)}
  before { allow_any_instance_of(HrisIntegrationsService::AdpWorkforceNowU::ManageSaplingProfileInAdp).to receive(:update).and_return(true)}

  it 'should run service and return true' do
    res = SendUpdatedEmployeeToAdpWorkforceNowJob.perform_now(user.id)
    expect(res).to eq(true)
  end
end