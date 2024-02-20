class ExportReportToSftp
  include Sidekiq::Worker
  sidekiq_options queue: :export_to_sftp_report, retry: false, backtrace: true

  def perform(report_id, user_id, company_id )
    company = Company.find_by_id(company_id)
    user = company.users.find_by_id(user_id)
    SftpService::ImmediateReportExport.new(report_id, user, company).perform
  end
end
