require 'csv'
require 'reports/report_fields_and_users_collection'
class PointInTimeReportJob < ApplicationJob
  queue_as :generate_big_reports

  def perform(user, report)
    collection = Reports::ReportFieldsAndUsersCollection.fetch_user_collection(report.company_id, report, user)
    if report.meta['recipient_type'] == 'sftp' || collection.results.count <= 300
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, collection.results.pluck(:id).uniq, user.id, false)
      [{file: file, name: report.name }]

    else
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.set(queue: 'point_in_time_report_job').perform_in(1.second, report.id, collection.results.pluck(:id).uniq, user.id, true)
      [{ inside_csv_job: true }]
    end
  end
end
