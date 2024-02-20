require 'csv'
require 'reports/report_fields_and_users_collection'
class WritePointInTimeReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  attr_accessor :point_in_time_date
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  def perform(report_id, ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    report = Report.find_by(id: report_id)    
    name = report.name.tr('/' , '_')
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.csv")
    @point_in_time_date = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue Date.today
    
    column_headers, fields_id = Reports::ReportFieldsAndUsersCollection.new.get_sreadsheet_fileds_and_custom_fields_reports(report)
    titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize.tr("\n", " ")  : ''}
    total ids.length
    CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
      report.company.users.where(id: ids).order("users.last_name asc").each_with_index do |user, index|
        at index, "#{name} - #{index}" if index%10 == 0
        field_histories = fetch_point_in_time_user_histories(user)
        writer << user.get_point_in_time_fields(column_headers, fields_id, report, field_histories)
      end
    end

    if send_email
      user = report.company.users.find_by(id: user_id)
      UserMailer.csv_report_email(user, report, name, file).deliver_now!
      File.delete(file) if file.present?
      at ids.length, "completed"
    else
      file
    end
  end

  private

  def fetch_point_in_time_user_histories(user)
    if user.profile
      if @point_in_time_date
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id).where("created_at <= ?", @point_in_time_date.end_of_day)
      else
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id)
      end
    else
      user.field_histories
    end
  end
end
