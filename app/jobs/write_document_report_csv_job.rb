require 'csv'
require 'reports/report_fields_and_users_collection'
class WriteDocumentReportCSVJob
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  attr_accessor :point_in_time_date
  sidekiq_options :queue => :generate_big_reports, :retry => false, :backtrace => true

  if Rails.env.development? || Rails.env.test?
      FILE_STORAGE_PATH = ("#{Rails.root}/tmp")
  else
      FILE_STORAGE_PATH = File.join(Dir.home, 'www/sapling/shared/')
  end

  def perform(report_id, paperwork_requests_ids, upload_request_ids, personal_document_ids, user_id, send_email=false, jid=nil)
    @jid ||= jid
    report = Report.find_by(id: report_id)
    user = report.company.users.find_by(id: user_id)
    report_service = ReportService.new()
    sort_params = report_service.get_sorting_params(report)
    order_in = sort_params[:order_in] == 'asc' ? 'asc' : 'desc'
    report_documents = []

    if sort_params[:order_column] == 'doc_name'
      report_documents = PaperworkRequest.where(id: paperwork_requests_ids).joins(:document).order("LOWER(documents.title) #{order_in}") +
                         UserDocumentConnection.joins(:document_connection_relation).where(id: upload_request_ids).joins(:document_connection_relation).order("LOWER(document_connection_relations.title) #{order_in}") +
                         PersonalDocument.where(id: personal_document_ids).order("LOWER(personal_documents.title) #{order_in}")
    elsif sort_params[:order_column] == 'due_date'
      report_documents = PaperworkRequest.where(id: paperwork_requests_ids).order("paperwork_requests.created_at #{order_in}") +
                         UserDocumentConnection.joins(:document_connection_relation).where(id: upload_request_ids).order("user_document_connections.created_at #{order_in}") +
                         PersonalDocument.where(id: personal_document_ids).order("personal_documents.created_at #{order_in}")
    end
    name = report.name.tr('/' , '_')
    file = File.join(FILE_STORAGE_PATH,"#{name}#{rand(1000)}.csv")
    column_headers = ["user_id", "company_email", "first_name", "last_name", "document_id", "title", "status", "assigned_at", "completed_at", "link"]
    titleize_permanent_fields = column_headers.map { |h| h.present? ? h.titleize : ''}
    total report_documents.length
    CSV.open(file, 'w:bom|utf-8', write_headers: true, headers: titleize_permanent_fields) do |writer|
      report_documents.each_with_index do |report_document, index|
        at index + 1, "#{name} - #{index}" if index%10 == 0
        writer << user.get_documents_fields_values(report_document)
      end
    end
    if send_email
      UserMailer.csv_report_email(user, report, name, file).deliver_now!
      File.delete(file) if file.present?
      at report_documents.length, "completed"
    else
      file
    end
  end
end
