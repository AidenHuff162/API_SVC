require 'rails_helper'

RSpec.describe GeneralDataProtectionRegulation::ConductActionAgainstUserJob, type: :job do 

  before { allow_any_instance_of(GdprService::GdprManagement).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = GeneralDataProtectionRegulation::ConductActionAgainstUserJob.perform_now(nil)
    expect(res).to eq(true)
  end
end