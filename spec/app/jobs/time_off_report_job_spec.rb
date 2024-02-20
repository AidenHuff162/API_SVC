require 'rails_helper'

RSpec.describe TimeOffReportJob, type: :job do
  let(:company) { create(:company) }
  let(:user) {create(:user, company: company)} 
  let!(:pto_policy) {create(:default_pto_policy, company: company)}
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, name: 'default', permanent_fields:[{"id"=>"ui", "position"=>0}, {"id"=>"fn", "position"=>1}], report_type: 1, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "pto_policy"=>"all_pto_policies", "sort_by"=>"start_date_desc", "employee_type"=>"all_employee_status"})}

  describe 'write csv report for user' do
    it 'should return file and name' do
      res = TimeOffReportJob.new.perform(user, report)
      expect(res[0].keys).to eq([:file, :name])
    end
  end
end 