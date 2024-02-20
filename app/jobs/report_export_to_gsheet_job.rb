require 'authorize_gsheet_credentials'
require 'reports/report_fields_and_users_collection'

class ReportExportToGsheetJob < ApplicationJob
  queue_as :generate_gsheet_reports
  include ActionController::Helpers

  def perform(report_id, user, report_name, company_id)
    @report = Report.find_by(id: report_id)
    if @report.present?

      authorizer = AuthorizeGsheetCredentials.get_authorizer
      credentials = authorizer.get_credentials_from_relation(user, user.id.to_i)

      if credentials.present?
        spread_sheet_service = GoogleService::SpreadsheetService.new(credentials)

        if @report.report_type == 'workflow' || @report.report_type == 'survey'
          collection = Reports::ReportFieldsAndUsersCollection
                      .fetch_task_user_connection_collection(company_id, @report, user)
        elsif @report.report_type == 'document'
          signatory_collection = Reports::ReportFieldsAndUsersCollection
                      .fetch_paperwork_requests_collection(company_id, @report, user)
          upload_collection = Reports::ReportFieldsAndUsersCollection
                      .fetch_upload_requests_collection(company_id, @report, user)
          personal_collection = Reports::ReportFieldsAndUsersCollection
                      .fetch_personal_requests_collection(company_id, @report, user)
          gsheet_url = spread_sheet_service.create_gsheet(@report, signatory_collection.results.map(&:id),
                      report_name, upload_collection.results.map(&:id), personal_collection.results.map(&:id))
        else
          collection = Reports::ReportFieldsAndUsersCollection
                      .fetch_user_collection(company_id, @report, user)
        end
        gsheet_url ||= spread_sheet_service.create_gsheet(@report, collection.results.map(&:id), report_name)

        UserMailer.gsheet_report_email(
          user, report_name, gsheet_url, company_id).deliver_now!
      else
        @report.update(gsheet_url: I18n.t('notifications.admin.report.invalid'))
      end
    end
  end
end
