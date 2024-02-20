module SftpService
  class ImmediateReportExport
    attr_reader :current_user, :current_company, :report_id

    def initialize(report_id, current_user, current_company)
      @report_id = report_id
      @current_user = current_user
      @current_company = current_company
    end

    def perform
      params = {:report_id => report_id }
      results = ReportService.new(params, current_user).perform 
      report = current_company.reports.find_by(id: report_id)
      file = if ['workflow', 'time_off'].include?(report.report_type)
                results[0][:file][:meta][:file]
              else
                results[0][:file]
              end

      name = report.name.tr('/' , '_')
      SftpService::SendFileToSftp.new(report.sftp, file, false,  name, current_user).perform    
    end  
  end
end
