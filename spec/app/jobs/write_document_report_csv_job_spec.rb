require 'rails_helper'

RSpec.describe WriteDocumentReportCSVJob, type: :job do
  let(:company) { create(:company) }
  let(:user) {create(:user, company: company)} 
  let(:report) {FactoryGirl.create(:report, report_creator_id: user.id, company_id: company.id, name: 'Doc Test Report', report_type: 3, user_id: user.id, meta: {"team_id"=>nil, "location_id"=>nil, "filter_by"=>"all_documents", "sort_by"=>"due_date_desc", "employee_type"=>"all_employee_status"})}
  let(:document_with_saved_template) { create(:document_with_paperwork_template, title: 'title', company_id: company.id) }
  let(:request1) { create(:paperwork_request, :request_skips_validate, document_id: document_with_saved_template.id, user_id: user.id, state: 'all_signed', signed_document: nil) }

  describe 'write csv report for documents' do
    it 'should return file name' do
      res = WriteDocumentReportCSVJob.new.perform(report.id, [request1.id], [], [], user.id)

      expect(res.include?(report.name)).to eq(true)
    end

    it 'should return file name and send email' do
      res = WriteDocumentReportCSVJob.new.perform(report.id, [request1.id], [], [], user.id, true)

      expect(res).to eq('OK')
    end

    it 'should return file name ' do
      report.meta[:sort_by]= 'doc_name_asc'
      report.save!
      res = WriteDocumentReportCSVJob.new.perform(report.id, [request1.id], [], [], user.id, false)

      expect(res.include?(report.name)).to eq(true)
    end

  end
end