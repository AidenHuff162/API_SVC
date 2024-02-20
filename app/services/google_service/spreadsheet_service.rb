require 'google/apis/sheets_v4'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'
require 'reports/report_fields_and_users_collection'

class GoogleService::SpreadsheetService
  attr_accessor :application_name, :credentials

  def initialize(credentials, application_name = 'Sapling GSheet')
    @application_name = application_name
    @credentials = credentials
  end

  def create_gsheet(report, ids, report_name, upload_request_ids = nil, personal_document_ids = nil)
    spreadsheet_data = []
    row_count = 0
    report_service = ReportService.new()
    sort_params = report_service.get_sorting_params(report)

    if report.report_type != 'track_user_change'
      if report.report_type == 'workflow'
        titleize_permanent_fields = ["Task Name", "Task ID", "Task Description", "Task Timing", "Task Timeline", "Workflow", "Workflow ID", "Task Owner ID", "Task Owner Name", "Task Receiver ID", "Task Receiver Name", "Workspace ID", "Workspace Name", "State", "Due Date", "Created At", "Updated At"]
      elsif report.report_type == 'document'
        spreadsheet_fields = ["user_id", "company_email", "first_name", "last_name", "document_id", "title", "status", "assigned_at", "completed_at", "link"]
        titleize_permanent_fields = spreadsheet_fields.map { |h| h.present? ? h.titleize : ''}
      elsif report.report_type == 'survey'
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
              SurveyQuestion.find_by(id: h).try(:question_text)
            end
          else
            ''
          end
        end
      else
        spreadsheet_fields, fields_id = Reports::ReportFieldsAndUsersCollection.new.get_sreadsheet_fileds_and_custom_fields_reports(report)
        titleize_permanent_fields = spreadsheet_fields.map { |field| field =="user_id" ? "User ID" : field.try(:titleize)&.tr("\n", " ") }
      end
      spreadsheet_data = time_off_meta(report) if report.report_type == 'time_off'
      spreadsheet_data.push(titleize_permanent_fields)

      if report.report_type == 'time_off'
        if report.meta["pto_policy"] == "all_pto_policies"
          pto_policies = Company.find(report.company_id).pto_policies
        else
          pto_policies = Company.find(report.company_id).pto_policies.where(id: report.meta["pto_policy"])
        end
        pto_policies.each do |pto_policy|
          report.company.users.where(id: ids).each do |user|
            if user.assigned_pto_policies.find_by(pto_policy_id: pto_policy.id)
              row_count = row_count + 1
              spreadsheet_data.push(user.get_timeoff_fields_values(spreadsheet_fields,fields_id, report, report.meta, pto_policy, pto_policy.assigned_pto_policy_ids))
            end
          end
        end
        row_count += 10

        @bulk_report = [Reports::ReportFieldsAndUsersCollection.bulk_time_off_headers]
        @bulk_report_count = 8
        pto_policies.each do |pto_policy|
          report.company.users.where(id: ids).find_each do |user|
            user.get_bulk_timeoff_fields_values(report, report.meta, pto_policy).each do |v|
              @bulk_report.push v
              @bulk_report_count += 1
            end
          end
        end
      elsif report.report_type == 'workflow'
        task_user_connections = TaskUserConnection.where(id: ids).order("task_user_connections.#{sort_params[:order_column]} #{sort_params[:order_in]}")
        task_user_connections.each do |record|
          row_count = row_count + 1
          spreadsheet_data.push(report.company.users.first.get_workflow_fields_values(record))
        end
        row_count += 10

        @comments_report = [Reports::ReportFieldsAndUsersCollection.workflow_tasks_comments_headers]
        @comments_report_count = 1
        task_user_connections.each do |record|
          record.comments.each do |comment|
            comm = report.company.users.first.get_workflow_tasks_comments(comment, record)
            @comments_report.push comm
            @comments_report_count += 1
          end
        end

        @sub_tasks_report = [Reports::ReportFieldsAndUsersCollection.workflow_tasks_subtasks_headers]
        @sub_tasks_report_count = 1
        task_user_connections.each do |record|
          record.task.sub_tasks.each do |sub_task|
            subtask = report.company.users.first.get_workflow_sub_tasks(sub_task)
            @sub_tasks_report.push subtask
            @sub_tasks_report_count += 1
          end
        end

      elsif report.report_type == 'document'
        report_documents = []
        
        if sort_params[:order_column] == 'doc_name'
          report_documents = PaperworkRequest.where(id: ids).joins(:document).order("LOWER(documents.title) #{sort_params[:order_in]}") +
                             UserDocumentConnection.joins(:document_connection_relation).where(id: upload_request_ids).joins(:document_connection_relation).order("LOWER(document_connection_relations.title) #{sort_params[:order_in]}") +
                             PersonalDocument.where(id: personal_document_ids).order("LOWER(personal_documents.title) #{sort_params[:order_in]}")
        elsif sort_params[:order_column] == 'due_date'
          report_documents = PaperworkRequest.where(id: ids).order("paperwork_requests.created_at #{sort_params[:order_in]}") +
                             UserDocumentConnection.joins(:document_connection_relation).where(id: upload_request_ids).order("user_document_connections.created_at #{sort_params[:order_in]}") +
                             PersonalDocument.where(id: personal_document_ids).order("personal_documents.created_at #{sort_params[:order_in]}")
        end

        report_documents.each do |report_document|
          row_count = row_count + 1
          spreadsheet_data.push(report.company.users.first.get_documents_fields_values(report_document))
        end
      elsif report.report_type == 'point_in_time'
        point_in_time_date = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue Date.today

        report.company.users.where(id: ids).order("users.last_name asc").each do |user|
          row_count = row_count + 1
          field_histories = fetch_point_in_time_user_histories(user, point_in_time_date)
          spreadsheet_data.push(user.get_point_in_time_fields(spreadsheet_fields, fields_id, report, field_histories))
        end
      elsif report.report_type == 'survey'
        task_user_connections = TaskUserConnection.where(id: ids).order("task_user_connections.#{Arel.sql(sort_params[:order_column])} #{Arel.sql(sort_params[:order_in])}")
        task_user_connections.each do |task_user_connection|
          row_count = row_count + 1
          spreadsheet_data.push(task_user_connection.get_survey_report_values(column_headers))
        end
      else
        custom_table = nil
        custom_table_report = report.custom_tables.select {|p| p['enabled_history'] == true}.first
        custom_table_name =custom_table_report['name'] rescue nil
        custom_table = report.company.custom_tables.find_by(name: custom_table_name)


        report.company.users.where(id: ids).order("users.#{sort_params[:order_column]} #{sort_params[:order_in]}").each do |user|
          custom_table_user_snapshots = user.custom_table_user_snapshots.where(custom_table_id: custom_table.id).order(effective_date: :desc) rescue nil if custom_table
          custom_table_user_snapshots = custom_table_user_snapshots.present? && custom_table_user_snapshots.count > 1 ? custom_table_user_snapshots : [1]
          custom_table_user_snapshots.each_with_index do |ctus, i|
            row_count = row_count + 1
            spreadsheet_data.push(user.get_fields_values(
            spreadsheet_fields,fields_id, report, ctus))
          end
        end
      end
    else
      report_permanent_fields = report.permanent_fields.pluck('id')
      spreadsheet_data.push([ 'Timestamp', 'Changed by Name', 'Changed by UserID', 'GUID',
                              fetch_permanent_fields(report_permanent_fields), 'Section/Table', 'Field ID',
                              'Field Name', 'Field Type', 'Old Value', 'New Value' ]).flatten
      
      report_permanent_field = report.permanent_fields.pluck('id')  
      reporting_fields, custom_fields, permanent_fields = Reports::ReportFieldsAndUsersCollection.get_fields_for_user_track_change_report(report)
      start_date = Date.strptime(report.meta['start_date'],'%m/%d/%Y') rescue nil
      end_date = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue nil
      company_users = report.company.users.where(id: ids)
      company_users.find_each(batch_size: 100) do |user|
        field_histories = fetch_user_histories(user, start_date, end_date)

        reporting_fields.each do |reporting_field|
          reporting_profile_field = fetch_reporting_profile_field(permanent_fields, custom_fields, reporting_field['id'])
          if reporting_profile_field
            profile_field_history = fetch_field_history(reporting_profile_field, field_histories)
            if profile_field_history.count > 0
              rows = user.get_tracked_field_values(reporting_profile_field, profile_field_history, report_permanent_fields)
              row_count = row_count + rows.count 
              spreadsheet_data.push(*rows)
            end
          end
        end
      end
    end

    sheet_service_response = export_to_drive(
                              spreadsheet_data, row_count+1, report_name, report.company_id, report.report_type)
    report.update(gsheet_url: sheet_service_response) unless report.meta["is_default"]
    return sheet_service_response
  end

  def export_to_drive (data, row_count, report_name, company_id, report_type)
    exception_occurred = false
    begin
      creation_time = DateTime.now
      service = Google::Apis::SheetsV4::SheetsService.new
      service.client_options.application_name = application_name
      service.client_options.send_timeout_sec = 120
      service.client_options.read_timeout_sec = 120

      service.authorization = credentials

      if Company.find(company_id).date_format == "dd/MM/yyyy"
        properties = Google::Apis::SheetsV4::SpreadsheetProperties.new(title: report_name, locale: "en_GB")
      else
        properties = Google::Apis::SheetsV4::SpreadsheetProperties.new(title: report_name)
      end

      request_body = Google::Apis::SheetsV4::Spreadsheet.new(properties: properties)
      if report_type == "time_off"
        add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
        add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new
        add_sheet_request.properties.title = 'Balances'
        request_body.sheets = []
        request_body.sheets.push add_sheet_request

      elsif report_type == "workflow"
        add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
        add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new
        add_sheet_request.properties.title = 'Workflows'
        request_body.sheets = []
        request_body.sheets.push add_sheet_request
      end

      response = service.create_spreadsheet(request_body)
      range = "A1:#{row_count}"
      request_body = Google::Apis::SheetsV4::ValueRange.new
      value_range_object = {
        major_dimension: "ROWS",
        values: data
      }

      service.update_spreadsheet_value(response.spreadsheet_id, range, value_range_object, value_input_option: 'USER_ENTERED')
      if report_type == 'time_off'
        add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
        add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new
        add_sheet_request.properties.title = 'Requests'

        batch_update_spreadsheet_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
        batch_update_spreadsheet_request.requests = Google::Apis::SheetsV4::Request.new

        batch_update_spreadsheet_request_object = [ add_sheet: add_sheet_request ]
        batch_update_spreadsheet_request.requests = batch_update_spreadsheet_request_object

        service.batch_update_spreadsheet(response.spreadsheet_id, batch_update_spreadsheet_request)
        bulk_range_object = {
                              major_dimension: "ROWS",
                              values: @bulk_report
                            }
        service.update_spreadsheet_value(response.spreadsheet_id, "'Requests'!A1:L#{@bulk_report_count}", bulk_range_object, value_input_option: 'USER_ENTERED')
      elsif report_type == 'workflow'
        add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
        add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new
        add_sheet_request.properties.title = 'Comments'

        tasks_comments_spreadsheet_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
        tasks_comments_spreadsheet_request.requests = Google::Apis::SheetsV4::Request.new

        tasks_comments_spreadsheet_request_object = [ add_sheet: add_sheet_request ]
        tasks_comments_spreadsheet_request.requests = tasks_comments_spreadsheet_request_object

        service.batch_update_spreadsheet(response.spreadsheet_id, tasks_comments_spreadsheet_request)
        comments_range_object = {
                              major_dimension: "ROWS",
                              values: @comments_report
                            }
        service.update_spreadsheet_value(response.spreadsheet_id, "'Comments'!A1:D#{@comments_report_count+1}", comments_range_object, value_input_option: 'USER_ENTERED')

        add_sheet_request = Google::Apis::SheetsV4::AddSheetRequest.new
        add_sheet_request.properties = Google::Apis::SheetsV4::SheetProperties.new
        add_sheet_request.properties.title = 'Subtasks'

        sub_tasks_spreadsheet_request = Google::Apis::SheetsV4::BatchUpdateSpreadsheetRequest.new
        sub_tasks_spreadsheet_request.requests = Google::Apis::SheetsV4::Request.new

        sub_tasks_spreadsheet_request_object = [ add_sheet: add_sheet_request ]
        sub_tasks_spreadsheet_request.requests = sub_tasks_spreadsheet_request_object

        service.batch_update_spreadsheet(response.spreadsheet_id, sub_tasks_spreadsheet_request)
        sub_tasks_range_object = {
                              major_dimension: "ROWS",
                              values: @sub_tasks_report
                            }
        service.update_spreadsheet_value(response.spreadsheet_id, "'Subtasks'!A1:F#{@sub_tasks_report_count+1}", sub_tasks_range_object, value_input_option: 'USER_ENTERED')
      end
      spreadsheet_url = response.spreadsheet_url
    rescue Exception => e
      LoggingService::GeneralLogging.new.create(Company.find_by(id: company_id), 'Export Google sheet', {result: "Exception = #{e.to_s}"})
      spreadsheet_url =  I18n.t('notifications.admin.report.invalid')
    end
    return spreadsheet_url
  end

  private

  def time_off_meta(report)
    policy_name = ""
    displaying_unit = "Hours"
    if report.meta["pto_policy"] == "all_pto_policies"
      policy_name = "all_pto_policies"
    elsif report.meta["pto_policy"].kind_of?(Array) && report.meta["pto_policy"].count > 1
      policy_name = "Multiple Policies"
    else
      pto_policy = PtoPolicy.find_by(company: report.company_id, id: report.meta["pto_policy"])
      policy_name = pto_policy.name
      displaying_unit = pto_policy.displaying_unit
    end
    results = []
    results << ['Report Name', report.name] << ['Policy Name', policy_name] << ['Displaying in', displaying_unit]
    results << ['Begin Date', get_date(report.meta['start_date'], report)] << ['End Date', get_date(report.meta['end_date'], report)]
    results << []
    results
  end

  def get_date(date, report)
    if date
      TimeConversionService.new(report.company).perform(Date.strptime(date, '%m/%d/%Y'))
    else
      'All Available Dates'
    end
  end

  def fetch_reporting_profile_field(permanent_fields, custom_fields, reporting_field_id)
    permanent_fields.detect { |permanent_field| permanent_field['id'] == reporting_field_id } || custom_fields.find_by(id: reporting_field_id)
  end

  def fetch_field_history(reporting_profile_field, field_histories)
    if reporting_profile_field['isDefault'] != nil
      if reporting_profile_field['name'] == 'Department'
        field_name = 'Team'
      elsif reporting_profile_field['name'] == 'About'
        field_name = 'About You'
      elsif reporting_profile_field['name'] == 'Job Title'
        field_name = 'Title'
      else
        field_name = reporting_profile_field['name']
      end

      return field_histories.where(field_name: field_name, custom_field_id: nil)
    else
      return field_histories.where(custom_field_id: reporting_profile_field['id'])
    end
  end

  def fetch_user_histories(user, start_date, end_date)
    if user.profile
      if start_date && end_date
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id).where("created_at >= ? AND created_at <= ?", start_date.beginning_of_day, end_date.end_of_day)
      else
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id)
      end
    else
      user.field_histories
    end
  end

  def fetch_point_in_time_user_histories(user, point_in_time_date)
    if user.profile
      if point_in_time_date
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id).where("created_at <= ?", point_in_time_date.end_of_day)
      else
        FieldHistory.where("(field_auditable_type = 'User' AND field_auditable_id = ?) OR (field_auditable_type = 'Profile' AND field_auditable_id = ?)", user.id, user.profile.id)
      end
    else
      user.field_histories
    end
  end

  def fetch_permanent_fields(permanent_fields)
    header_fields = []
    default_fields = ActiveSupport::HashWithIndifferentAccess.new({
                                                                    ui: 'UserID',
                                                                    fn: 'First Name',
                                                                    ln: 'Last Name',
                                                                    ce: 'Company Email'})
    default_field_keys = default_fields.keys
    permanent_fields.try(:each) do |field|
      header_fields << default_fields[field] if default_field_keys.include?(field)
    end

    header_fields
  end
end
