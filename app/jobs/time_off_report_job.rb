require 'csv'
require 'reports/report_fields_and_users_collection'
class TimeOffReportJob < ApplicationJob
  queue_as :generate_big_reports
  def perform(user, report)
    update_start_end_date(report)
    collection = Reports::ReportFieldsAndUsersCollection.fetch_user_collection(report.company_id, report, user)
    ids = collection&.results.pluck(:id).uniq
    if report.meta['recipient_type'] == 'sftp'|| (!report.company.subdomain.eql?('docplanner') && collection.results.count <= 500 && PtoRequest.where(user_id: ids).count <= 500)
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.new.perform(report.id, ids, user.id, false)
      [{file: file, name: report.name }]
    else
      file = "Write#{report.report_type.camelize}ReportCSVJob".constantize.set(queue: 'time_off_report_job').perform_in(1.second, report.id, ids, user.id, true)
      [{ inside_csv_job: true }]
    end

  end

  private

  def update_start_end_date report
    report_service = ReportService.new()
    required_dates = report_service.get_start_end_date(report)
    return unless required_dates.present?
    is_report_change = false

    date_range_type = report.meta['date_range_type'] rescue nil
    if date_range_type.present? && date_range_type == 4
      required_dates[:start_date] = required_dates[:start_date].strftime('%m/%d/%Y') rescue nil
      required_dates[:end_date] = required_dates[:end_date].strftime('%m/%d/%Y') rescue nil
    end

    if required_dates[:start_date].present? && required_dates[:start_date] != report.meta['start_date']
      report.meta['start_date'] = required_dates[:start_date]
      is_report_change = true
    end

    if required_dates[:end_date].present? && required_dates[:end_date] != report.meta['end_date']
      report.meta['end_date'] = required_dates[:end_date]
      is_report_change = true
    end
    
    report.save! if is_report_change
  end
end
