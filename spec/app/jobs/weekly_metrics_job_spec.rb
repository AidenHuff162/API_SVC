require 'rails_helper'

RSpec.describe WeeklyMetricsJob, type: :job do
  let(:company) { create(:company) }
  before do
  	allow_any_instance_of(RoiEmailManagementServices::CalculateWeeklyStatistics).to receive(:perform) { {} }
  end

  describe 'write csv report for workflow' do
    it 'should return file and name' do
      res = WeeklyMetricsJob.new.perform(company.id)
      expect(res.first.class).to eq(CustomEmailAlert)
    end
  end
end