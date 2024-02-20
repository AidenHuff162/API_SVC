module Api
  module V1
    module Admin
      class ReportsController < ApiController
        before_action :require_company!
        before_action :set_custom_fields_to_nil_if_attribtues_are_empty, only: :update

        before_action only: [:index] do
          ::PermissionService.new.checkAdminVisibility(current_user, params[:sub_tab])
        end
        rescue_from CanCan::AccessDenied do |exception|
          render body: Sapling::Application::EMPTY_BODY, status: 204 if params[:sub_tab].present?
        end

        load_and_authorize_resource
        authorize_resource only: [:index, :show, :show_with_user_roles, :report_csv, :export_report_to_sftp]

        def index
          collection = ReportsCollection.new(custom_report_params)
          respond_with collection.results, each_serializer: ReportSerializer::Basic
        end

        def get_reports
          collection = ReportsCollection.new(report_table_params)
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.results.count,
            recordsFiltered: collection.nil? ? 0 : collection.results.count,
            data: ActiveModelSerializers::SerializableResource.new(collection.results, each_serializer: ReportSerializer::FilterData)
          }
        end

        def show_with_user_roles
          respond_with @report, serializer: ReportSerializer::WithUserRoles
        end

        def create
          form = ReportForm.new(update_params_for_admin(report_create_params))
          form.save!
          respond_with form, serializer: ReportSerializer::Basic
        end

        def show
          respond_with @report, serializer: ReportSerializer::Basic
        end

        def update
          form = ReportForm.new(custom_report_params)
          form.save!
          respond_with form, serializer: ReportSerializer::Basic
        end

        def duplicate
          report = @report.deep_clone include: :custom_field_reports
          report.name = "Copy of #{report.name}"
          report.report_creator_id = current_user.id
          report.save!
          respond_with report, serializer: ReportSerializer::Basic
        end

        def update_with_user_roles
          form = ReportForm.new(custom_report_params)
          form.save!
          respond_with form, serializer: ReportSerializer::WithUserRoles, company: current_company
        end

        def destroy
          @report.destroy
          head 204
        end

        def last_viewed
          temp_params = custom_report_params
          temp_params['last_view'] = DateTime.now
          report = current_company.reports.find_by(id: temp_params[:id])
          report.update({last_view: DateTime.now})

          respond_with report, serializer: ReportSerializer::Basic
        end

        def report_csv
          results = ReportService.new(params, current_user).perform
          report = current_company.reports.find_by(id: params[:report_id])
          if results[0][:inside_csv_job]
            respond_with inside_csv_job: true
          else
            if report && (report.time_off? || report.workflow?)
              respond_with sheet: results[0][:file]
              file = results[0][:file]
              File.delete(file[:meta][:file]) if file[:meta][:file].present? && File.exist?(file[:meta][:file])
            else
              file = results[0][:file]
              @content = {
              file: CSV.read(file, :liberal_parsing => true),
              name: results[0][:name]
              }
              File.delete(file) if File.exist?(file)
              respond_with @content.to_json
            end
          end
        end

        def export_report_to_sftp
          ExportReportToSftp.perform_async(params['id'], current_user.id, current_company.id)
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private

        def set_custom_fields_to_nil_if_attribtues_are_empty
          report = current_company.reports.find_by(id: params[:id])
          if report
            report.custom_field_reports.destroy_all if params[:custom_field_reports].blank?
          end
        end

        def report_create_params
          params.merge(company_id: current_company.id, user_id: current_user.id, last_view: DateTime.now)
        end

        def custom_report_params
          params.permit(:id, :name, :last_view, :report_type, :sftp_id, :user_role_ids => []).merge(company_id: current_company.id, user_id: current_user.id).merge(meta: params[:meta], permanent_fields: params[:permanent_fields],custom_tables: params[:custom_tables], users: params[:users], custom_field_reports: params[:custom_field_reports], term: params["search"].present? && params["search"]["value"].present? ? params["search"]["value"]: nil)
        end

        def report_table_params
          page = (params[:start].to_i / params[:length].to_i) + 1
          sort_column = params["columns"][params["order"]["0"]["column"]]["data"]
          sort_order = params["order"]["0"]["dir"]
          params.permit(:id, :name, :last_view, :report_type,:user_role_ids => []).merge(company_id: current_company.id, user_id: current_user.id).merge(meta: params[:meta], permanent_fields: params[:permanent_fields],custom_tables: params[:custom_tables], users: params[:users], custom_field_reports: params[:custom_field_reports], term: params["search"].present? && params["search"]["value"].present? ? params["search"]["value"]: nil).merge(
            page: page,
            per_page: params[:length].to_i,
            order_column: sort_column,
            order_in: sort_order
          )
        end

        def update_params_for_admin(report_params)
          return report_params unless current_user.admin?

          {
            team_permission_level: 'team_id',
            status_permission_level: 'employee_type',
            location_permission_level: 'location_id'
          }.each do |permission_level, param_level|
            user_permissions = current_user.user_role[permission_level]
            if param_level == 'employee_type'
              if report_params['meta'][param_level].include?('all_employee_status')
                report_params['meta'][param_level] = user_permissions if user_permissions.exclude?('all') 
              else
                report_params['meta'][param_level] &= user_permissions
              end
            else
              if report_params['meta'][param_level] && user_permissions.exclude?('all')
                report_params['meta'][param_level] &= current_user.user_role[permission_level].map(&:to_i)
              end
            end
          end
          report_params
        end

      end
    end
  end
end
