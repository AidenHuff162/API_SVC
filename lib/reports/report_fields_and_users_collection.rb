module Reports
  class ReportFieldsAndUsersCollection
    SPLIT_DELIMITER = "\n"

    def self.fetch_user_collection (company_id, report, user)
      UsersCollection.new(report_csv_params(company_id, report, user))
    end

    def self.fetch_task_user_connection_collection (company_id, report, user)
      TaskUserConnectionsCollection.new(report_csv_params(company_id, report, user).merge(include_deleted: true))
    end

    def self.fetch_paperwork_requests_collection (company_id, report, user)
      PaperworkRequestsCollection.new(report_csv_params(company_id, report, user))
    end

    def self.fetch_upload_requests_collection (company_id, report, user)
      UserDocumentConnectionCollection.new(report_csv_params(company_id, report, user))
    end

    def self.fetch_personal_requests_collection (company_id, report, user)
      PersonalDocumentsCollection.new(report_csv_params(company_id, report, user))
    end

    def self.report_csv_params(companyid, report, user)
      report_service = ReportService.new()
      sort_params = report_service.get_sorting_params(report)
      filter_parmas = report_service.get_filter_params(report, user)
      date_range_object = report_service.get_start_end_date(report)
      report_service.update_start_end_date(report, date_range_object) if (['track_user_change', 'time_off'].include? report.report_type) && !report.meta['schedule_type'].eql?('never')
      params = filter_parmas
      params.merge!(company_id: companyid,
                   order_column: sort_params[:order_column],
                   order_in: sort_params[:order_in])

      if report.report_type == 'time_off'
        params.merge(pto_policy_id: report.meta['pto_policy'],
                     registered: !report.meta['inactive_users'])

      elsif report.report_type == 'workflow'
        params.merge(due_date_start_range: date_range_object[:start_date],
                     due_date_end_range: date_range_object[:end_date],
                     workflow_report: true,
                     tasks_ids: report.meta['tasks_ids'])
      elsif report.report_type == 'survey'
        params.merge(due_date_start_range: date_range_object[:start_date],
                     due_date_end_range: date_range_object[:end_date],
                     survey_report: true,
                     survey_id: report.meta['survey_id']
                    )
      elsif report.report_type == 'document'
        params.merge(exclude_drafts: true, user_state_filter: report.meta['user_state_filter'].try(:downcase))

      elsif report.report_type == 'track_user_change'
        params.merge(hire_start_date_range: nil,
                     hire_end_date_range: nil)

      elsif report.report_type == 'point_in_time'
        params.merge(point_in_time_date: date_range_object[:end_date],
                     registered: !report.meta['inactive_users'])

      else
        params.merge(hire_start_date_range: date_range_object[:start_date],
                     hire_end_date_range: date_range_object[:end_date])
      end
    end

    def get_sreadsheet_fileds_and_custom_fields_reports (report)
      spreadsheet_fields = []
      fields_id = []
      begin
        if report.name == "default"
          employment_status = report.company.custom_fields.find_by(name: "Employment Status")
          employment_status_report = CustomFieldReport.new(custom_field: employment_status, report: report, position: 9)
          custom_field_reports = [employment_status_report]
          custom_field_reports_positions = [9]
        else
          custom_field_reports = report.custom_field_reports.includes(custom_field: [:sub_custom_fields]) rescue nil
          custom_field_reports_positions = custom_field_reports.pluck(:position) rescue nil
        end

        other_section_positions = []
        other_section_positions = report.meta['other_section'].map{ |p| p['position'] } if report.meta.has_key? "other_section"

        permanent_fields_positions = report.permanent_fields.map{ |p| p['position'] }
        custom_tables_positions = report.custom_tables.map{ |p| p['position'] }
        iterator_count = (custom_field_reports_positions | permanent_fields_positions | custom_tables_positions | other_section_positions).max
        @index = 0
        for i in 0..iterator_count
          if custom_field_reports_positions.include? i
            insert_custom_fields(custom_field_reports, i, report, spreadsheet_fields, fields_id)
          elsif permanent_fields_positions.include? i
            insert_permanent_fields(report, spreadsheet_fields, fields_id)
          elsif custom_tables_positions.include? i
            insert_custom_tables(report, i, spreadsheet_fields, fields_id)
          elsif other_section_positions.include? i
            insert_other_section_field(report, i, spreadsheet_fields, fields_id)
          end
        end
      rescue Exception => e
        LoggingService::GeneralLogging.new.create(report.try(:company), 'Create Email - Schedule Report Job', {result: 'Failed to add fields', error: e.message, report_id: report.id })           
      end
      [spreadsheet_fields, fields_id]
    end

    def self.get_survey_report_column_headers(report)
      column_headers = ["receiver_user_id", "receiver_first_name", "receiver_last_name", "receiver_company_email", "owner_user_id", "owner_first_name", "owner_last_name", "owner_company_email", "survey_name", "survey_sent_at", "survey_completed_at"]
      survey = Survey.find_by(id: report.meta["survey_id"])
      report.meta["questions_ids"].each do |question_id|
        column_headers << question_id
      end
      column_headers
    end

    def self.bulk_time_off_headers
      ['Request ID', 'First Name', 'Last Name', 'Email', 'Policy Name', 'Policy ID', 'Begin Date', 'End Date', 'Description', 'Status', 'Amount Requested', 'Created at']
    end

    def self.workflow_tasks_comments_headers
      ['Task ID', 'Comment Description', 'Comment Owner', 'Created at']
    end

    def self.workflow_tasks_subtasks_headers
      ['Subtask ID', 'Subtask Title', 'Task ID', 'State', 'Created at', 'Updated at']
    end

    def self.fetch_custom_table_reports(report)
      custom_tables = report.custom_tables
      custom_table_reports = []
      
      custom_tables.each do |custom_table|
        report.company.prefrences['default_fields'].each { |default_field| custom_table_reports.push({'id' => default_field['id'], 'position' => custom_table['position']}) if default_field['custom_table_property'] == custom_table['section']}
        report.company.custom_fields.joins(:custom_table).where('custom_tables.name = ?', custom_table['name']).each { |custom_field| custom_table_reports.push({'id' => custom_field['id'], 'position' => custom_table['position']}) }
      end if custom_tables.present? && custom_tables.count != 0

      custom_table_reports
    end

    def self.fetch_reporting_fields(report, custom_field_reports, permanent_field_reports, custom_table_reports)
      reporting_fields = permanent_field_reports + custom_table_reports
      report.custom_field_reports.each { |custom_field_report| reporting_fields.push({'id' => custom_field_report.custom_field_id, 'position' => custom_field_report.position}) }
      reporting_fields
    end

    def self.fetch_reporting_field_ids(custom_field_reports, permanent_field_reports, custom_table_reports)
      custom_field_ids = custom_field_reports.pluck(:custom_field_id)
      permanent_field_ids = permanent_field_reports.map { |permanent_field_report| permanent_field_report['id'] }
      custom_table_ids = custom_table_reports.map { |custom_table_report| custom_table_report['id'] }
      custom_field_ids + permanent_field_ids + custom_table_ids
    end

    def self.get_fields_for_user_track_change_report(report)
      custom_field_reports = report.custom_field_reports
      permanent_field_reports = report.permanent_fields.select { |permanent_field| !['fn', 'ln', 'ce', 'ui'].include? permanent_field['id'] }
      custom_table_reports = self.fetch_custom_table_reports(report)

      reporting_fields = self.fetch_reporting_fields(report, custom_field_reports, permanent_field_reports, custom_table_reports)
      reporting_field_ids = self.fetch_reporting_field_ids(custom_field_reports, permanent_field_reports, custom_table_reports)

      custom_fields = report.company.custom_fields.where(id: reporting_field_ids)
      permanent_fields = report.company.prefrences['default_fields'].select { |default_field| reporting_field_ids.include? default_field['id'] }

      [reporting_fields, custom_fields, permanent_fields]
    end

    def insert_other_section_field(report, iterator, spreadsheet_fields, fields_id)
      field = report.meta['other_section'].select{ |p| p['position'] == iterator }
      spreadsheet_fields.push(
            Report::FIELDS_MAPPING[field[0]['id']])
      fields_id.push('other_section')
    end

    def check_integration_type(report)
      report.company.integration_type != 'namely' && report.permanent_fields[@index].present? && report.permanent_fields[@index]['id'] == 'jbt' ? true : false
    end

    def insert_custom_fields(custom_field_reports, iterator, report, spreadsheet_fields, fields_id)
      custom_field = custom_field_reports
              .select{ |p| p.position == iterator }
              .first.custom_field

      if SubCustomField.show_sub_custom_fields(custom_field) && custom_field.sub_custom_fields.present?
        sort_by = custom_field.currency? ? :name : :id
        sub_fields = custom_field.sub_custom_fields.sort_by &sort_by
        sub_fields.each do |field|
          if custom_field.field_type == 'currency'
            spreadsheet_fields.push(field.name == 'Currency Type' ? custom_field.name + SPLIT_DELIMITER + "Currency" : custom_field.name + SPLIT_DELIMITER + "Number")
          elsif custom_field.field_type == 'address'
            if field.name != "Country"
              report.point_in_time? ? spreadsheet_fields.push(field.name) : spreadsheet_fields.push(custom_field.name + SPLIT_DELIMITER + field.name)
              if field.name == "Zip"
                country_field = sub_fields.select{ |sf| sf.name == "Country" }.first
                report.point_in_time? ? spreadsheet_fields.push(country_field.name) : spreadsheet_fields.push(custom_field.name + SPLIT_DELIMITER + country_field.name)                
              end
            end
          else
            spreadsheet_fields.push(field.name)
          end
          fields_id.push(custom_field.id)
        end
      else
        if custom_field.name == "Effective Date" && custom_field.custom_table_id.present?
          table_name = custom_field.company.custom_tables.find_by(id: custom_field.custom_table_id).try(:name)
          spreadsheet_fields.push("Effective Date (#{table_name})")
        else
          spreadsheet_fields.push(custom_field.name)
        end
        fields_id.push(custom_field.id)
      end
    end

    def insert_custom_table_custom_fields(field, custom_table, spreadsheet_fields, fields_id)
      if field["name"] == "Effective Date"
        spreadsheet_fields.push("Effective Date (#{custom_table["name"]})")
      elsif field["field_type"] == 14 || field["field_type"] == "currency"
        spreadsheet_fields.push(field["name"] + SPLIT_DELIMITER + "Currency")
        spreadsheet_fields.push(field["name"] + SPLIT_DELIMITER + "Number")
        fields_id.push "custom_table#{SPLIT_DELIMITER}#{custom_table["id"]}"
      else
        spreadsheet_fields.push(field["name"])
      end
      fields_id.push "custom_table#{SPLIT_DELIMITER}#{custom_table["id"]}"
    end

    def insert_custom_table_default_fields(field, custom_table, spreadsheet_fields, fields_id)
      spreadsheet_fields.push(field["name"])
      fields_id.push("custom_table#{SPLIT_DELIMITER}#{custom_table.id}")
    end

    def insert_custom_tables(report, i, spreadsheet_fields, fields_id)
      custom_table_report = report.custom_tables.select {|p| p['position'] == i}.first
      custom_table_name = custom_table_report['name'] rescue nil
      custom_table = report.company.custom_tables.find_by(name: custom_table_name)
      if custom_table.present?
        table_custom_fields = custom_table.custom_fields
        for i in table_custom_fields
          insert_custom_table_custom_fields(i, custom_table, spreadsheet_fields, fields_id)
        end
        table_default_fields = report.company.prefrences['default_fields'].select{ |p| p["custom_table_property"] == custom_table.custom_table_property}
        for i in table_default_fields
          insert_custom_table_default_fields(i, custom_table, spreadsheet_fields, fields_id)
        end
      end
    end

    def insert_permanent_fields (report, spreadsheet_fields, fields_id)
      if report.permanent_fields[@index] && report.permanent_fields[@index]['id'].present?
        if !check_integration_type(report)
          spreadsheet_fields.push(
            Report::FIELDS_MAPPING[report.permanent_fields[@index]['id']])
          fields_id.push(0)
          @index = @index + 1
        else
          @index = @index + 1
        end
      end
    end
  end
end
