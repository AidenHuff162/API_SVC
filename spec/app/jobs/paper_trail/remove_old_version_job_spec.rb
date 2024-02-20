require 'rails_helper'

RSpec.describe PaperTrail::RemoveOldVersionJob, type: :job do 

  before { allow_any_instance_of(Interactions::PaperTrail::RemoveOldVersion).to receive(:perform).and_return(true)}

  it 'should run service and return true' do
    res = PaperTrail::RemoveOldVersionJob.perform_now
    expect(res).to eq(true)
  end
end