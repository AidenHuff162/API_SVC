require 'rails_helper'

RSpec.describe PeriodicJobs::Pto::TriggerPtoCalculations, type: :job do
  let!(:company) {FactoryGirl.create(:company, enabled_time_off: true, time_zone: "UTC")}
  context 'at midnight' do
    before do
      time = Time.now.utc()
      Time.stub(:now) {time.change(hour: 0)}
    end

    it 'should enque a job in sidekiq' do
      expect{ PeriodicJobs::Pto::TriggerPtoCalculations.new.perform }.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(1)
    end
  end

  context 'at start of period' do
    before do
      time = Time.now.utc()
      Time.stub(:now) {time.change(hour: 19)}
    end
    it 'should enque a job in sidekiq' do
      expect{ PeriodicJobs::Pto::TriggerPtoCalculations.new.perform }.to change{ActiveJob::Base.queue_adapter.enqueued_jobs.count}.by(1)
    end
  end
end
