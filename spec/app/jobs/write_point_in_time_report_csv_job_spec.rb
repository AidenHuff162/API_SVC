require 'rails_helper'

RSpec.describe WritePointInTimeReportCSVJob, type: :job do
  let(:company) { create(:company) }
  let(:user) {create(:user, company: company)} 
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, name: 'default', report_type: 5, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}

  describe 'write csv report for point in time' do
    it 'should return file name' do
      res = WritePointInTimeReportCSVJob.new.perform(report.id, [user.id], user.id)

      expect(res.include?(report.name)).to eq(true)
    end

    it 'should return file name and send email' do
      res = WritePointInTimeReportCSVJob.new.perform(report.id, [user.id], user.id, true)

      expect(res).to eq('OK')
    end

    it 'should return file name ' do
      res = WritePointInTimeReportCSVJob.new.perform(report.id, [user.id], user.id, false)

      expect(res.include?(report.name)).to eq(true)
    end

  end
end