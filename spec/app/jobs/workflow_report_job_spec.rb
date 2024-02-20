require 'rails_helper'

RSpec.describe WorkflowReportJob, type: :job do
  let(:company) { create(:company) }
  let(:user) {create(:user, company: company)} 
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, name: 'default', permanent_fields:[{"id"=>"ui", "position"=>0}, {"id"=>"fn", "position"=>1}], report_type: 2, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}

  describe 'write csv report for workflow' do
    it 'should return file and name' do
      res = WorkflowReportJob.new.perform(user, report)
      expect(res[0].keys).to eq([:file, :name])
    end
  end
end