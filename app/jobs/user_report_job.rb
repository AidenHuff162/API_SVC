require 'csv'
require 'reports/report_fields_and_users_collection'
class UserReportJob < ApplicationJob
  queue_as :generate_big_reports
  def perform(user, report)
    collection_ids = Reports::ReportFieldsAndUsersCollection.fetch_user_collection(report.company_id, report, user)&.results.pluck(:id).uniq
    enabled_history_table = report.custom_tables.select { |p| p['enabled_history'].present? }.first
    if report.meta['recipient_type'] == 'sftp' || !report.id.present? || (!enabled_history_table && collection_ids.present? && collection_ids.count <= 300 && report.custom_field_reports.count <= 10)
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, collection_ids, user.id, false, report)
      [{file: file, name: report.name}]
    else
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.set(queue: 'user_report').perform_in(1.second, report.id, collection_ids, user.id, true)
      [{ inside_csv_job: true }]
    end

  end
end
