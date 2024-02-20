require 'google/api_client/client_secrets'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'authorize_gsheet_credentials'
require 'reports/report_fields_and_users_collection'

module Api
  module V1
    module Admin
      class GsheetsController < ApiController
        before_action :set_base_url

        APPLICATION_NAME = 'Sapling GSheet'

        def export_to_google_sheet
          if params && params[:report_id] == "default"
            report = Report.default_report(current_user.company, params)

          elsif params && params[:report_id] == "turnover"
            report = Report.turnover_report(current_user.company, params)
          else
            report = current_company.reports.find_by(id: params[:report_id])
          end
          report_name = report.get_report_name_with_time
          authorizer = AuthorizeGsheetCredentials.get_authorizer
          
          credentials = authorizer.get_credentials_from_relation(current_user, current_user.try(:id).try(:to_i))
          logger.info "----Credentials-------"

          if ['workflow', 'survey'].include?(report.report_type)
            collection = Reports::ReportFieldsAndUsersCollection
                        .fetch_task_user_connection_collection(current_company.id, report, current_user)
          elsif report.report_type == 'document'
            collection = Reports::ReportFieldsAndUsersCollection
                        .fetch_paperwork_requests_collection(current_company.id, report, current_user)
            upload_collection = Reports::ReportFieldsAndUsersCollection
                        .fetch_upload_requests_collection(current_company.id, report, current_user)
            personal_collection = Reports::ReportFieldsAndUsersCollection
                        .fetch_personal_requests_collection(current_company.id, report, current_user)           
          else
            collection = Reports::ReportFieldsAndUsersCollection
                        .fetch_user_collection(current_company.id, report, current_user)
          end

          if report.report_type == 'document'
            background_processing, gsheet_url_repsonse = create_report(report, credentials, collection, current_company.id, current_user, upload_collection, personal_collection)
          else
            background_processing, gsheet_url_repsonse = create_report(report, credentials, collection, current_company.id, current_user)
          end

          respond_with response: gsheet_url_repsonse, background_processing: background_processing
        end

        def get_authorization_status
          authorizer = AuthorizeGsheetCredentials.get_authorizer
          credentials = authorizer.get_credentials_from_relation(current_user, current_user.id.to_i)
          logger.info credentials
          response = authorizer.get_authorization_url( base_url: @base_url, state: JsonWebToken.encode(report_id: params[:report_id], company_id: current_company.id, user_id: current_user.id, report_params: { date_filter: params[:date_filter], filters: params[:filters] }))
          
          if credentials.present?
            begin
              credentials.fetch_access_token!
              response = 200
              create_integration_api_logging(current_company, 'GSheet', 'Authorization Status', 'N/A', { result: response.to_s }, 200)
            rescue Exception => e
              authorizer.revoke_authorization_from_relation(current_user, current_user.id.to_i)
              create_integration_api_logging(current_company, 'GSheet', 'Authorization Status', 'N/A', { error: e.message }, 500)
              response = response
            end
          end

          respond_with response: response
        end

        def gsheet_oauth2callback
          begin
            str = JsonWebToken.decode(params[:state])
            return if str.blank?

            company = Company.find_by(id: str[:company_id])
            return if company.blank?

            current_user = company.users.find_by(id: str[:user_id])
            report_params = str[:report_params]

            report = case str[:report_id]
                     when 'default'
                      Report.default_report(company, report_params)
                     when 'turnover'
                      Report.turnover_report(company, report_params)
                     else
                      company.reports.find_by(id: str[:report_id])
                     end
            return if report.blank?

            authorizer = AuthorizeGsheetCredentials.get_authorizer
            credentials = authorizer.get_and_store_credentials_from_code_relation( current_user, user_id: current_user.get_google_auth_credential_id, code: params[:code], base_url: @base_url )
            
            upload_collection, personal_collection = [nil] * 2
            if ['workflow', 'survey'].include?(report.report_type)
              collection = Reports::ReportFieldsAndUsersCollection
                           .fetch_task_user_connection_collection(str[:company_id], report, current_user)
            elsif report.report_type == 'track_user_change'
              collection = []
            elsif report.report_type == 'document'
              collection = Reports::ReportFieldsAndUsersCollection
                           .fetch_paperwork_requests_collection(str[:company_id], report, current_user)
              upload_collection = Reports::ReportFieldsAndUsersCollection
                                  .fetch_upload_requests_collection(str[:company_id], report, current_user)
              personal_collection = Reports::ReportFieldsAndUsersCollection
                                    .fetch_personal_requests_collection(str[:company_id], report, current_user)

            else
              collection = Reports::ReportFieldsAndUsersCollection
                           .fetch_user_collection(str[:company_id], report, current_user)
            end
            background_processing, gsheet_url_repsonse = create_report(report, credentials, collection, str[:company_id], current_user, upload_collection, personal_collection)
            
            app_domain = Rails.env.development? ? 'http://rocketship.sapling.localhost:3000' : "https://#{company.app_domain}"
            redirect_to "#{app_domain}/#/reports?ghseet_url=#{gsheet_url_repsonse}&gsheet_background_processing=#{background_processing}"          

          rescue Exception => e
            create_integration_api_logging(current_company, 'GSheet', 'Auth', 'N/A',  {error: e.message}, 500)
          end
        end

        def set_base_url
          @base_url = request.host.include?("saplingapp.io") ? "https://www.saplingapp.io/api/v1/gsheet_oauth2callback" : "https://#{request.host}/api/v1/gsheet_oauth2callback"
        end

        private

        def create_report(report, credentials, collection, company_id, user, upload_collection = nil, personal_collection = nil)
          custom_fields = report.custom_field_reports.count
          if !report.id.present? || (collection.try(:results).try(:count).to_i < 300 && custom_fields < 11)
            if report.present? && credentials.present?
              report_name = report.get_report_name_with_time
              spread_sheet_service = GoogleService::SpreadsheetService.new(credentials)

              gsheet_url_repsonse = spread_sheet_service.create_gsheet(report, collection.results.map(&:id), report_name,
                                    upload_collection&.results&.map(&:id), personal_collection&.results&.map(&:id)) if collection.try(:results)
              background_processing = false
            end
          else
            if report.present? && credentials.present?
              report_name = report.get_report_name_with_time
              ReportExportToGsheetJob.perform_later(
                report.id, user, report_name, company_id)
              gsheet_url_repsonse = report_name
              background_processing = true
            end
          end
          return background_processing, gsheet_url_repsonse
        end

      end
    end
  end
end
