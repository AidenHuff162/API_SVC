require 'rails_helper'

RSpec.describe WeeklyHiresEmailJob, type: :job do
  let!(:company) { create(:company) }
  before do
    allow_any_instance_of(Time).to receive(:wday) {1}
  	allow_any_instance_of(WeeklyHiresEmailService).to receive(:perform) { true }
  end

  describe 'send emails for new hires' do
    it 'should return file and name' do
      res = WeeklyHiresEmailJob.new.perform
      expect(res.class).to eq(Array)
    end
  end
end