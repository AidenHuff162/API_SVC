require 'csv'
require 'reports/report_fields_and_users_collection'
class WorkflowReportJob < ApplicationJob
  queue_as :generate_big_reports
  def perform(user, report)
    collection_ids = Reports::ReportFieldsAndUsersCollection.fetch_task_user_connection_collection(report.company_id, report, user)&.results.pluck(:id).uniq
    if report.meta['recipient_type'] == 'sftp'|| collection_ids&.count <= 100
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, collection_ids, user.id, false)
      [{file: file, name: report.name}]
    else
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.set(queue: 'workflow_report_job').perform_in(1.second, report.id, collection_ids, user.id, true)
      [{ inside_csv_job: true }]
    end
  end
end
