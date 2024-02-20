require 'csv'
require 'reports/report_fields_and_users_collection'
class WriteUserReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true
  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end
  
  def perform(report_id, ids, user_id, send_email=false, user_report=nil, jid=nil)
    @jid ||= jid
    report = user_report
    report = Report.find_by(id: report_id) unless user_report
    name = report.name.tr('/' , '_')
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.csv")
    column_headers, fields_id = Reports::ReportFieldsAndUsersCollection.new.get_sreadsheet_fileds_and_custom_fields_reports(report)
    titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize.tr("\n", " ") : ''}
    custom_table = nil
    custom_table_report = report.custom_tables.select {|p| p['enabled_history'] == true}.first
    custom_table_name =custom_table_report['name'] rescue nil
    custom_table = report.company.custom_tables.find_by(name: custom_table_name)

    report_service = ReportService.new()
    sort_params = report_service.get_sorting_params(report)
    total ids.length
    CSV.open(
      file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
        ids.each_slice(200).with_index do |id, index|
          report.company.users.where(id: id).order("users.#{sort_params[:order_column]} #{sort_params[:order_in]}").each_with_index do |user, nested_index|
            custom_table_user_snapshots = fetch_custom_table_user_snapshots(user, custom_table)
            at (index *  200) + nested_index, "#{name} - #{(index *  200) + nested_index}" if nested_index%10 == 0
            custom_table_user_snapshots.each_with_index do |ctus, i|
            begin
              writer << user.get_fields_values(column_headers, fields_id, report, ctus)
            rescue Exception => e
              LoggingService::GeneralLogging.new.create(report.try(:company), 'Report Generate', {result: 'Failed to add values', error: e.message, report_id: report.id })
            end
          end
        end
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

  def fetch_custom_table_user_snapshots(user, custom_table)
    ctus = filter_custom_table_user_snapshots(user, custom_table) if custom_table.present?
    ctus && ctus.count.positive? ? ctus : [1]
  end

  def filter_custom_table_user_snapshots(user, custom_table)
    ctus = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).order(created_at: :desc)
    return ctus if ctus.blank? || custom_table.standard?
    ctus.where('effective_date <= ?', Date.current).reorder(effective_date: :desc)
  end
end
