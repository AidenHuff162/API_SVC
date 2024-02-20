require 'rails_helper'

RSpec.describe WriteTimeOffReportCSVJob, type: :job do
  let(:company) { create(:company) }
  let(:user) {create(:user, company: company)} 
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, name: 'default', report_type: 1, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "pto_policy"=>"all_pto_policies", "employee_type"=>"all_employee_status"})}
  let(:pto_policy) { create(:default_pto_policy, company: company)}
  before do
    pto_policy.update(is_enabled: true)
  end
  describe 'write csv report for time off' do
    it 'should return data' do
      res = WriteTimeOffReportCSVJob.new.perform(report.id, [user.id], user.id)
      expect(res[:requests].present?).to eq(true)
    end

    it 'should return  for particular policy' do
      report.meta['pto_policy'] = [pto_policy.id]
      report.save!
      res = WriteTimeOffReportCSVJob.new.perform(report.id, [user.id], user.id)
      
      expect(res[:requests].present?).to eq(true)
    end

    it 'should return  for particular policy' do
      report.meta['pto_policy'] = pto_policy.id
      report.save!
      res = WriteTimeOffReportCSVJob.new.perform(report.id, [user.id], user.id)
      
      expect(res[:requests].present?).to eq(true)
    end

    it 'should return send email' do
      expect{WriteTimeOffReportCSVJob.new.perform(report.id, [user.id], user.id, true)}.to change{company.company_emails.count}.by(1)
    end
  end
end