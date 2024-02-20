require 'rails_helper'
RSpec.describe PeriodicJobs::Users::SetUserCurrentStage, type: :job do
  it 'should enque SetUserCurrentStage job in sidekiq' do
    expect{ PeriodicJobs::Users::SetUserCurrentStage.perform_async }.to change { Sidekiq::Queues["default"].size }.by(1)
  end
end