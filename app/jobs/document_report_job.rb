require 'csv'
require 'reports/report_fields_and_users_collection'
class DocumentReportJob < ApplicationJob
  queue_as :generate_big_reports
  def perform(user, report)
    signatory_collection = Reports::ReportFieldsAndUsersCollection.fetch_paperwork_requests_collection(report.company_id, report, user)
    upload_collection = Reports::ReportFieldsAndUsersCollection.fetch_upload_requests_collection(report.company_id, report, user)
    personal_collection = Reports::ReportFieldsAndUsersCollection.fetch_personal_requests_collection(report.company_id, report, user)
    
    if report.meta['recipient_type'] == 'sftp' || (signatory_collection.results.count + upload_collection.results.count + personal_collection.results.count <= 300)
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, signatory_collection&.results.pluck(:id).uniq, upload_collection&.results.pluck(:id).uniq, personal_collection&.results.pluck(:id).uniq, user.id, false)
      [{file: file, name: report.name}]

    else
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.set(queue: 'document_report_job').perform_in(1.second, report.id, signatory_collection&.results.pluck(:id).uniq, upload_collection&.results.pluck(:id).uniq, personal_collection&.results.pluck(:id).uniq, user.id, true)
      [{ inside_csv_job: true }]
    end

  end
end
