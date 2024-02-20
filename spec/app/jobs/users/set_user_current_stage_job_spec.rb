require 'rails_helper'

RSpec.describe Users::SetUserCurrentStageJob, type: :job do
  before { allow_any_instance_of(Interactions::Users::SetUserCurrentStage).to receive(:perform).and_return(true)}
  let!(:company) { create(:company) }

  it 'should run service and return true' do
    res = Users::SetUserCurrentStageJob.new.perform(company)
    expect(res).to eq(true)
  end
end