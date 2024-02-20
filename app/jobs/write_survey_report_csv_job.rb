require 'csv'
require 'reports/report_fields_and_users_collection'
class WriteSurveyReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  attr_accessor :point_in_time_date
  sidekiq_options :queue => :generate_big_reports, :retry => 0, :backtrace => true

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  def perform(report_id, task_user_connections_ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    report = Report.find_by(id: report_id)
    user = report.company.users.find_by(id: user_id)
    report_service = ReportService.new()
    sort_params = report_service.get_sorting_params(report)
    task_user_connections = TaskUserConnection.joins(:user).with_deleted.where(id: task_user_connections_ids).order("task_user_connections.#{Arel.sql(sort_params[:order_column])} #{Arel.sql(sort_params[:order_in])}")
    name = report.name.tr('/' , '_')
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.csv")
    column_headers = Reports::ReportFieldsAndUsersCollection.get_survey_report_column_headers(report)
    titleize_permanent_fields = column_headers.map do |h|
      if h.present?
        if h.class == String # Constant column headers
          if ["owner_user_id", "receiver_user_id"].include?(h)
            "#{h.titleize} ID"
          else
            h.titleize
          end
        elsif h.class == Fixnum # Represents the id of a SurveyQuestion
          SurveyQuestion.find_by(id: h).try(:question_text).gsub(/\[CompanyName\]/, report.company.name)
        end
      else
        ''
      end
    end
    
    total task_user_connections.length
    CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
      task_user_connections.each_with_index do |task_user_connection, index|
        at index + 1, "#{name} - #{index}" if index%10 == 0
        writer << task_user_connection.get_survey_report_values(column_headers)
      end
    end
    if send_email
      UserMailer.csv_report_email(user, report, name, file).deliver_now!
      File.delete(file) if file.present?
      at task_user_connections.length, "completed"
    else
      file
    end
  end

end
