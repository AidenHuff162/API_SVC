class ScheduleReportService < ApplicationService
  attr_reader :report

  def initialize(report)
    @report = report
  end

  def call; get_schedule_report_queue end

  private
  
  def get_schedule_report_queue
    if report.report_type == 'user'
      user_collection_ids = Reports::ReportFieldsAndUsersCollection.fetch_user_collection(report.company_id, report, nil)&.results.map(&:id)&.uniq
      column_headers, fields_id = Reports::ReportFieldsAndUsersCollection.new.get_sreadsheet_fileds_and_custom_fields_reports(report)
      return (user_collection_ids.count > 500 && column_headers.count > 35) ? 'big_user_schedule_report' : 'user_schedule_report' 
    else
      return get_queue_name
    end
  end

  def get_queue_name
    (report.report_type == 'survey' ? 'workflow' : report.report_type) + '_report_job'  
  end
end
