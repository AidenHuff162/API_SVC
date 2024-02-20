module GsheetFieldValues
  extend ActiveSupport::Concern
  SPLIT_DELIMITER = "\n"
  CHECK_EMAIL_REGEXP = Devise.email_regexp #this is being used to check csv injection

  def get_fields_values fields, fields_id, report = nil, ctus = nil
    fields_values = []
    custom_field_values = self.custom_field_values
    plain_values = get_plain_text_field_values fields_id, custom_field_values
    
    fields.each_with_index do |field, index|
      if fields_id[index].to_s.split(SPLIT_DELIMITER)[0] == 'custom_table'
        fields_values.push(handle_csv_values(get_custom_table_field(field, ctus, report, fields_id[index].split(SPLIT_DELIMITER)[1])))
      elsif plain_values[field].present?
        custom_field = self.company.custom_fields.find_by(name: field)
        if CustomField::TAX_FIELDS_WITH_REGEX.keys.include?(custom_field.field_type.to_sym)
          fields_values.push(get_formatted_tax_value(custom_field.field_type, plain_values[field]))
        else
          fields_values.push(handle_csv_values(plain_values[field]))
        end
      elsif fields_id[index] == 0 || fields_id[index] == 'other_section'
        fields_values.push(handle_csv_values(get_prefrence_field(field)))
      elsif fields_id[index].to_i > 0
        custom_field = self.company.custom_fields.find_by(id: fields_id[index])
        fields_values.push('') && next unless custom_field
        if custom_field.custom_table_id
          fields_values.push(handle_csv_values(get_custom_table_field(field, [1], report, custom_field.custom_table_id)))
        else
          fields_values.push(handle_csv_values(return_gsheet_custom_field(field, custom_field_values, custom_field)))
        end  
      end
    end
    fields_values
  end


  def get_custom_field_history_data field, field_histories
    field_histories.where(field_name: field.name).last.try(:new_value) rescue nil
  end

  def getHomeAddressSubPart(address, sub_custom_field)
    sub_parts = eval(address)
    sub_part = ''

    case sub_custom_field
    when 'Line 1'
      sub_part = sub_parts['Line 1'] || sub_parts[:line1]
    when 'Line 2'
      sub_part = sub_parts['Line 2'] || sub_parts[:line2]
    when 'City'
      sub_part = sub_parts['City'] || sub_parts[:city]
    when 'Country'
      sub_part = sub_parts['Country'] || sub_parts[:country]
    when 'State'
      sub_part = get_state_key(sub_parts['State']) || get_state_key(sub_parts[:state])
    when 'Zip'
      sub_part = sub_parts['Zip'] || sub_parts[:zip]
    end

    sub_part
  end

  def get_state_key(state_name)
    state_key = State.where("key = ? OR name = ?", state_name, state_name).take&.key
    (state_key && (state_key =~ /\d/).nil?) ? state_key : state_name
  end

  def get_point_in_time_fields fields, fields_id, report, field_histories
    fields_values = []
    date = Date.strptime(report.meta['end_date'],'%m/%d/%Y') rescue Date.today
    fields.each_with_index do |field,index|
      if fields_id[index].to_s.split(SPLIT_DELIMITER)[0] == 'custom_table'
        fields_values.push(handle_csv_values(get_point_in_time_table_data(field, report, fields_id[index].split(SPLIT_DELIMITER)[1])))
      elsif fields_id[index] == 0
        custom_table_id = is_table_default_field(field, fields_id[index])
        if custom_table_id.present?
          fields_values.push(handle_csv_values(get_point_in_time_table_data(field, report, custom_table_id)))
        else
          fields_values.push(handle_csv_values(get_prefrence_field(field)))
        end
      elsif fields_id[index].to_i > 0
        custom_field = report.company.custom_fields.find_by(id: fields_id[index])
        if custom_field.custom_table_id
          fields_values.push(handle_csv_values(get_point_in_time_table_data(field, report, custom_field.custom_table_id)))
        else
          value = get_custom_field_history_data(custom_field, field_histories)
          value = value.to_date.strftime(report.company.get_date_format) if custom_field.field_type == "date" && value
          if custom_field.field_type == 'address' && value != nil
            fields_values.push(handle_csv_values(getHomeAddressSubPart(value, field)))
          else
            fields_values.push(handle_csv_values(value))
          end
        end
      end
    end
    fields_values
  end

  def get_approved_ctus_field_values(fields, colec, has_approval)
    fields_values = []
    fields.each_with_index do |field, index|
      if fields.find_index("#{field}") == index
          if fields.find_index("EffectiveDate") == index || fields.find_index("ApprovedOn") == index || fields.find_index("RequestedDate") == index || fields.find_index("TableUpdated") == index
            if fields.find_index("EffectiveDate") == index || fields.find_index("ApprovedOn") == index
              formated_date = TimeConversionService.new(self.company).perform(colec[index].to_date) rescue ''
            else
              formated_date = colec[index]&.to_time&.strftime(format_time_and_date(self.company,colec[index].to_time)) rescue ''
            end
            fields_values.push(handle_csv_values(formated_date))
          elsif fields.find_index('OldValue') == index
            value, field_type = get_custom_snapshot_and_field(colec[index], true)
            old_value = format_snapshot_value(value, field_type, has_approval)
            fields_values.push(handle_csv_values(old_value))
          elsif fields.find_index('NewValue') == index
            value, field_type = get_custom_snapshot_and_field(colec[index])
            new_value = format_snapshot_value(value, field_type, has_approval)
            fields_values.push(handle_csv_values(new_value))
          else
            fields_values.push(handle_csv_values(colec[index]))
          end  
      end  
    end  
    fields_values
  end

  def get_approved_csa_field_values(fields, colec, has_approval)
    requested_field = RequestedField.find_by_id(colec[6])
    fields_values = []
    fields.each_with_index do |field, index|
      begin
        if fields.find_index("#{field}") == index
            if fields.find_index("ApprovedOn") == index || fields.find_index("RequestedDate") == index || fields.find_index("SectionUpdated") == index
              if fields.find_index("ApprovedOn") == index
                formated_date = TimeConversionService.new(self.company).perform(colec[index].to_date) rescue ''
              else
                formated_date = colec[index]&.to_time&.strftime(format_time_and_date(self.company,colec[index].to_time)) rescue ''
              end
              fields_values.push(handle_csv_values(formated_date))
            elsif fields.find_index('FieldName') == index
              fields_values.push(handle_csv_values(get_field_name(requested_field)))
            elsif fields.find_index('OldValue') == index
              old_value = get_old_value(requested_field)
              fields_values.push(handle_csv_values(old_value))
            elsif fields.find_index('NewValue') == index
              value, field_type, preferred_field_id = get_requested_field_and_type(requested_field)
              new_value = format_custom_section_value(value, field_type, has_approval, preferred_field_id)
              fields_values.push(handle_csv_values(new_value))
            else
              fields_values.push(handle_csv_values(colec[index]))
            end
        end
      rescue
        fields_values = nil
      end
    end
    fields_values
  end

  def get_field_name(requested_field)
    field_name = requested_field.custom_field.try(:name)
    field_name = self.company.prefrences["default_fields"].select { |default_field|  default_field['api_field_id'] == requested_field.preference_field_id }.try(:first)['name'] rescue nil if field_name.nil?
    return field_name
  end

  def get_old_value(requested_field)
    field_name = get_field_name(requested_field)
    field_value = self.field_histories.where('field_name ILIKE ? AND created_at < ?', field_name, requested_field.created_at).order(created_at: :desc).take.try(:new_value)
    field_value = self.profile.field_histories.where('field_name ILIKE ? AND created_at < ?', field_name, requested_field.created_at).order(created_at: :desc).take.try(:new_value) if field_value.nil?
    field_value
  end

  def get_requested_field_and_type(requested_field)
      value = [requested_field&.custom_field_value, requested_field&.field_type, requested_field&.preference_field_id]
  end

  def format_time_and_date(company,time)
    date_format = company.date_format.downcase

    case date_format
    when 'mm/dd/yyyy'
      time.strftime('%m/%d/%y %H:%M:%S')
    when 'dd/mm/yyyy'
      time.strftime('%d/%m/%Y %H:%M:%S')
    when 'yyyy/mm/dd'
      time.strftime('%Y/%m/%d %H:%M:%S')
    when 'mmm dd, yyyy'
      time.strftime('%b %d, %Y %H:%M:%S')
    else
      time
    end
  end

  def is_table_default_field field, field_data
    return false unless field_data == 0
    default_field = self.company.prefrences["default_fields"].select { |default_field| default_field if default_field['name'] == field.titleize && default_field['custom_table_property'].present? }.try(:first) rescue nil
    default_field.present? ? default_field['custom_table_property'] : nil
  end

  def get_documents_fields_values report_document=nil
    fields_values = []
    company_email = ""
    first_name = ""
    last_name = ""
    completed_at = ""
    assigned_at = TimeConversionService.new(self.company).perform(report_document&.created_at.to_date)
    user = report_document&.user
    document_url = ""
    report_document_fields = []
    if user.present?
      company_email = user.email
      first_name = user.first_name
      last_name = user.last_name
    end
    
    if report_document&.class == PaperworkRequest
      if (!report_document.co_signer_id.present? && report_document.state == 'signed') || (report_document.co_signer_id && report_document.state == 'all_signed')
        completed_at = TimeConversionService.new(self.company).perform(report_document.sign_date.to_date) if report_document.sign_date.present?
        document_url = report_document.signed_document_url unless report_document.signed_document.blank?
      elsif report_document.state == 'assigned' || (report_document.co_signer_id && report_document.state == 'signed' )
        document_url = report_document.unsigned_document_url unless report_document.unsigned_document.blank?
      end
      report_document_fields = [ report_document.user_id, company_email, first_name, last_name, report_document.document_id,
      report_document.document.title, report_document.state, assigned_at, completed_at,
      document_url ]
    elsif report_document&.class == UserDocumentConnection
      completed_at = TimeConversionService.new(self.company).perform(report_document.updated_at.to_date) if report_document.completed?
      document_url = report_document.attached_files.take.file.url rescue ""
      report_document_fields = [ report_document.user_id, company_email, first_name, last_name, report_document.document_connection_relation_id,
      report_document.document_connection_relation.title, report_document.state, assigned_at, completed_at,
      document_url ]
    elsif report_document&.class == PersonalDocument
      completed_at = TimeConversionService.new(self.company).perform(report_document.updated_at.to_date)
      document_url = report_document.attached_file.file.url rescue ""
      report_document_fields = [ report_document.user_id, company_email, first_name, last_name, report_document.id,
      report_document.title, "completed", assigned_at, completed_at,
      document_url ]
    end
        

    unless document_url.blank?
      document_url = "=HYPERLINK(\"#{document_url}\", \"#{document_url}\")"
    end

    report_document_fields.each do |value|
      fields_values << handle_csv_values(value)
    end
    fields_values
  end

  def get_workflow_fields_values record=nil
    fields_values = []
    task_name = ""
    task_description = ""
    workspace_name = ""
    workspace = record.workspace
    task = record.task
    task_name = ReplaceTokensService.new.replace_tokens(task.name, record.user)
    task_name = Nokogiri::HTML(task_name).xpath("//*[p]").first.content rescue " "

    if task.description
      task_description = ReplaceTokensService.new.replace_tokens(task.description, record.user)
      task_description = Nokogiri::HTML(task_description).xpath("//*[p]").first.content rescue " "
    end
    due_date = TimeConversionService.new(self.company).perform(record.due_date.to_date) if record.due_date.present?
    created_at = TimeConversionService.new(self.company).perform(record.created_at.to_date) if record.created_at.present?
    updated_at = TimeConversionService.new(self.company).perform(record.updated_at.to_date) if record.updated_at.present?
    state = record.overdue? ? 'overdue' : record.state

    if workspace.present?
      workspace_name = workspace.name
      owner_name = ''
      owner_id = ''
    elsif task.task_type == 'jira'
      owner_name = 'JIRA'
      owner_id = ''
    elsif task.task_type == 'service_now'
      owner_name = 'ServiceNow'
      owner_id = ''
    else    
      owner_name = (record.owner && record.owner.preferred_full_name) || ''
      owner_id = record.owner_id
    end

    fields_values.push(task_name, task.id, task_description, task.deadline_in, task.time_line, task.workstream.name, task.workstream.id, owner_id, owner_name, record.user_id, ((record.user && record.user.preferred_full_name) || ''), record.workspace_id, workspace_name, state, due_date, created_at, updated_at)
    fields_values
  end

  def get_workflow_tasks_comments comment=nil, record=nil
    fields_values = []
    task_id = nil
    task_id = record.task_id if record.task_id.present?
    comment_description = ""

    comment_description= comment.description if comment.description.present?
    while comment_description.include? "USERTOKEN" do
      comment.mentioned_users.each do |m|
        string_to_replace = "USERTOKEN[" + m.to_s + "]"
        user = self.company.users.find_by_id(m)
        comment_description = comment_description.sub string_to_replace, user.first_name if user.present?
      end
    end

    comment_owner = ""
    comment_owner = comment.commenter.preferred_full_name if comment.commenter.present?
    created_at = ""
    created_at = TimeConversionService.new(self.company).perform(comment.created_at.to_date) if comment.created_at.present?

    fields_values.push(task_id, comment_description, comment_owner, created_at)
    fields_values
  end

  def get_workflow_sub_tasks sub_task=nil, user_connection_id=nil
    fields_values = []
    if sub_task.present?
      sub_task_user_connection = user_connection_id.present? ? sub_task.sub_task_user_connections.with_deleted.find_by_task_user_connection_id(user_connection_id) : sub_task
      if sub_task_user_connection
        created_at = TimeConversionService.new(self.company).perform(sub_task_user_connection.created_at.to_date) if sub_task_user_connection.created_at.present?
        updated_at = TimeConversionService.new(self.company).perform(sub_task_user_connection.updated_at.to_date) if sub_task_user_connection.updated_at.present?

        fields_values.push(sub_task.id, sub_task.title, sub_task.task_id, sub_task_user_connection.state, created_at, updated_at)
      end
    end
    fields_values
  end

  def get_tracked_field_values(field_id, field_histories, report_permanent_fields = nil)
    field_histories = field_histories.order(created_at: :desc)
    field_histories.map.with_index do |field_history, index|
      get_profile_field_histories_data(field_id, field_history, field_histories[index + 1], report_permanent_fields)
    end
  end

  def get_bulk_timeoff_fields_values report, meta, pto_policy
    fields_values = []
    start_date = Date.strptime(meta['start_date'],'%m/%d/%Y') if meta['start_date'].present?
    end_date = Date.strptime(meta['end_date'],'%m/%d/%Y') if meta['end_date'].present?
    if meta['start_date'] == nil && meta['end_date'] == nil
      PtoRequestService::ManagePtoRequestInterceptingData.new(self, pto_policy, fields_values, meta).manage_pto_requests_intercepts_without_range 
    else
      PtoRequestService::ManagePtoRequestInterceptingData.new(self, pto_policy, fields_values, meta).manage_pto_requests_intercepts_with_range(start_date, end_date)
    end
    fields_values
  end

  def get_timeoff_fields_values fields, fields_id, report = nil, meta, pto_policy, assigned_pto_policy_ids
    plain_values = get_plain_text_field_values fields_id, custom_field_values
    assigned_policy = self.assigned_pto_policies.find_by(pto_policy_id: pto_policy.id)
    balance_factor = assigned_policy.pto_policy.balance_factor
    fields_values = []
    start_date = Date.strptime(meta['start_date'],'%m/%d/%Y') if meta['start_date'].present?
    end_date = Date.strptime(meta['end_date'],'%m/%d/%Y') if meta['end_date'].present?
    if meta['start_date'] == nil && meta['end_date'] == nil
      audit_logs = PtoBalanceAuditLog.where(assigned_pto_policy_id: assigned_pto_policy_ids, user_id: self.id).order('created_at ASC')
    else
      audit_logs = PtoBalanceAuditLog.where(assigned_pto_policy_id: assigned_pto_policy_ids, user_id: self.id, balance_updated_at: (start_date..end_date)).order('created_at ASC')
    end

    if audit_logs.size == 0
      audit_logs = nil
    end

    if meta['include_unapproved_timeoff'] == true
      status = [0, 1]
    else
      status = 1
    end

    pto_requests = self.pto_requests.where(pto_policy_id: pto_policy.id)
    fields.each_with_index do |field,index|
      if(field.casecmp("accrued") == 0)
        accrued = audit_logs.where('description LIKE ?',"Accr%").pluck('balance_added').inject(0){|sum,x| sum + x } rescue 0
        fields_values.push(get_amount_to_display(accrued, balance_factor))
      elsif(field.casecmp("used") == 0)
        balance_used = 0
        used_requests = pto_requests.where('begin_date <= ?', self.company.time.to_date).where(status: status)
        if !used_requests.nil? && meta['end_date'] == nil
          balance_used = used_requests.pluck('balance_hours').inject(0){|sum,x| sum + x }
        elsif !used_requests.nil? && meta['end_date'] != nil && meta['start_date'] != nil
          balance_used = used_requests.where("begin_date >= ? AND begin_date <= ?", start_date, end_date).pluck('balance_hours').inject(0){|sum,x| sum + x }
        end
        fields_values.push(get_amount_to_display(balance_used, balance_factor))
      elsif(field.casecmp("rollover_balance")== 0)
        rollover_balance = assigned_policy.carryover_balance
        fields_values.push(get_amount_to_display(rollover_balance, balance_factor))
      elsif(field.casecmp("beginning balance") == 0)
        beginning_balance = 0
        if audit_logs.present?
          audit_log = audit_logs.first
          beginning_balance = audit_log.balance + audit_log.balance_used - audit_log.balance_added if audit_log.present?
        else
          if start_date
            log = assigned_policy.pto_balance_audit_logs.where('balance_updated_at < ?', start_date).order('created_at DESC').first
            beginning_balance = log.balance if !log.nil?
          end
        end
        fields_values.push(get_amount_to_display(beginning_balance, balance_factor))
      elsif(field.casecmp("ending balance") == 0)
        ending_balance = 0
        if audit_logs.present?
          ending_balance = audit_logs.last.balance
        else
          if end_date && assigned_policy.pto_balance_audit_logs.present?
            log = assigned_policy.pto_balance_audit_logs.where('balance_updated_at > ?', end_date).order('created_at ASC').first
            ending_balance = log.balance + log.balance_used - log.balance_added if !log.nil?
            ending_balance = assigned_policy.total_balance if log.nil? && end_date >= assigned_policy.pto_balance_audit_logs.order('created_at ASC').first.balance_updated_at
          end
        end
        fields_values.push(get_amount_to_display(ending_balance, balance_factor))
      elsif(field.casecmp("scheduled") == 0)
        scheduled_requests = 0
        scheduled_requests = pto_requests.where(status: status)
        if !scheduled_requests.nil? && meta['end_date'] == nil
          scheduled_requests = scheduled_requests.where("begin_date > ? AND begin_date <= ?", self.company.time.to_date, self.company.time.to_date.end_of_year).pluck('balance_hours').inject(0){|sum,x| sum + x }
        elsif !scheduled_requests.nil? && meta['end_date'] != nil && meta['start_date'] != nil
          scheduled_requests = scheduled_requests.where("begin_date >= ? AND begin_date <= ? AND balance_deducted = false AND begin_date > ?", start_date, end_date, self.company.time.to_date).pluck('balance_hours').inject(0){|sum,x| sum + x }
        end
        fields_values.push(get_amount_to_display(scheduled_requests, balance_factor))
      elsif(field.casecmp("adjustments") == 0)
        used = audit_logs.where("description LIKE 'Manual adjustment%' OR description LIKE 'Policy Renewed' OR description LIKE 'Carryover Expired' OR description LIKE 'Deleted Adjustment'").pluck('balance_used').inject(0){|sum,x| sum + x} rescue 0
        added = audit_logs.where("description LIKE'Manual adjustment%' OR description LIKE 'Policy Renewed' OR description LIKE 'Carryover Expired' OR description LIKE 'Deleted Adjustment'").pluck('balance_added').inject(0){|sum,x| sum + x} rescue 0
        adjustments = (added - used)
        fields_values.push(get_amount_to_display(adjustments, balance_factor))
      elsif(field.casecmp("time_off_type") == 0)
          timeofftype = assigned_policy.pto_policy.policy_type
          fields_values.push(timeofftype)
      elsif(field.casecmp("policy_names") == 0)
        policyname = assigned_policy.pto_policy.name
        fields_values.push(policyname)
      elsif fields_id[index].to_s.split(SPLIT_DELIMITER)[0] == 'custom_table'
        ctus = self.custom_table_user_snapshots.where(custom_table_id: fields_id[index].split(SPLIT_DELIMITER)[1]).last
        fields_values.push(get_custom_table_field(field, ctus, report, fields_id[index].split(SPLIT_DELIMITER)[1]))
      elsif plain_values[field].present?
        fields_values.push(plain_values[field])
      elsif fields_id[index] == 0 || fields_id[index] == 'other_section'
        fields_values.push(get_prefrence_field(field))
      elsif fields_id[index].to_i > 0
        custom_field = self.company.custom_fields.find_by(id: fields_id[index])
        if custom_field.custom_table_id
          fields_values.push(get_custom_table_field(field, [1], report, custom_field.custom_table_id))
        else
          fields_values.push(return_gsheet_custom_field(field, custom_field_values, custom_field))
        end
      end
    end
    fields_values
  end

  def get_plain_text_field_values fields_id, custom_field_values
    values = custom_field_values.joins(:custom_field).where(custom_fields: {id: fields_id, field_type: CustomField::FIELD_TYPE_WITH_PLAIN_TEXT})
    plain_values = {}

    values.each do |value|
      begin
        value_text = value.value_text
        value_text = TimeConversionService.new(self.company).perform(value_text) if value_text.present? && value.custom_field && value.custom_field.date?
        plain_values[value.custom_field.name] = value_text
      rescue
        next
      end
    end

    plain_values
  end

  private
  def get_amount_to_display balance, factor
    return (balance/factor).round(2)
  end

  def handle_csv_values value
    (value.present? && should_add_quotes?(value)) ? "'#{value}'" : value
  end

  def get_custom_snapshot_and_field(id, old_value = false)
    snapshot = CustomSnapshot.find_by_id(id)
    return unless snapshot

    snapshot = fetch_old_snapshot(snapshot) if old_value
    fetch_value(snapshot)
  end

  def fetch_old_snapshot(snapshot)
    applied_ctus = snapshot.custom_table_user_snapshot
    CustomTableUserSnapshot.get_previous_approved_ctus(applied_ctus.id, applied_ctus.user_id, applied_ctus.custom_table_id, applied_ctus.effective_date)
                           .second&.custom_snapshots&.find_by_custom_field_id(snapshot.custom_field_id)
  end

  def fetch_value(snapshot)
    return nil unless snapshot

    type = snapshot.custom_field&.field_type
    value = if type == 'coworker'
              CustomField.get_coworker_value(snapshot.custom_field, snapshot.custom_table_user_snapshot&.user_id)
            else
              snapshot.custom_field_value
            end
    [value, type]
  end

  def format_custom_section_value(value, type, has_approval, preferred_field_id = nil)
    return nil if !has_approval || value.nil?

    formatted_value = if type == 'date'
                        if value['value_text']
                          TimeConversionService.new(self.company).perform(value['value_text'].to_date)
                        else
                          value
                        end
                      elsif ['short_text', 'long_text', 'social_security_number', 'social_insurance_number', 'number', 'simple_phone', 'confirmation'].include?(type)
                        value = value['value_text'] if value['value_text']
                        value
                      elsif ['mcq', 'employment_status'].include?(type)
                        if preferred_field_id == "access_permission"
                          self.company.user_roles.find_by(id: value)&.name
                        else
                          id = value['custom_field_option_id']
                          CustomFieldOption.find_by_id(id)&.option
                        end
                      elsif type == 'multi_select'
                        options= ""
                        ids = value['checkbox_values']
                        CustomFieldOption.where(id: ids).each do |field|
                          options += field.option+ ', '
                        end
                        options
                      elsif ['address', 'tax', 'currency'].include?(type)
                        new_value= ""
                        value['sub_custom_fields'].each do |sub_field_value|
                          new_value += sub_field_value['custom_field_value']['value_text']+ ', ' if sub_field_value['custom_field_value'] != nil
                        end
                        new_value
                      elsif type == 'phone'
                        phone_number = ''
                        country_code = ''
                        phone = ''
                        area = ''              
                        value['sub_custom_fields'].each do |sub_field_value|
                          if sub_field_value['custom_field_value'] != nil
                            sub_value = sub_field_value['custom_field_value']['value_text']
                            country = sub_value if sub_field_value['name'] == "Country"
                            country_code = ISO3166::Country.find_country_by_alpha3(country)&.country_code if country
                            phone = sub_value if sub_field_value['name'] == "Phone"
                            area = sub_value if sub_field_value['name'] == "Area code"              
                          end
                        end
                        phone_number = '+'+country_code+'-'+area+'-'+phone
                      elsif type == "coworker"
                        if ['buddy', 'manager'].include?(preferred_field_id)
                          self.company.users.find_by(id: value)&.first_name + ' ' + self.company.users.find_by(id: value)&.last_name
                        else
                          value = value['coworker']['first_name'].to_s + ' ' + value['coworker']['last_name'].to_s
                          value
                        end
                      else
                        value
                      end
  end

  def format_snapshot_value(value, type, has_approval)
    return nil if !has_approval || value.nil?
    
    formatted_value = if type == 'Date'
                        TimeConversionService.new(self.company).perform(value.to_date)
                      elsif (type == 'Short Text' || type == 'Long Text' )
                        "'#{value}'" if value && value.scan(/\D/).empty?
                      elsif ['mcq', 'multi_select', 'employment_status'].include?(type)
                        CustomFieldOption.find_by_id(value)&.option
                      else
                        value
                      end
  end

  def should_add_quotes?(value)
    # check if string contains operators and digits only OR starts with -+=@|
    ((value =~ /^[-+=@|]/) || (value =~ /^[^a-zA-Z]+$/ && value =~ /[-+=|]/ && value =~ /[0-9]/))
  end

  def get_formatted_tax_value(tax_type , tax_value)
    return '' unless tax_value
    tax_value.gsub(/[^0-9]/, '').gsub(CustomField::TAX_FIELDS_WITH_REGEX[tax_type.to_sym], '\1-\2-\3') 
    tax_value
  end

end
