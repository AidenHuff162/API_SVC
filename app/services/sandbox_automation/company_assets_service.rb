class SandboxAutomation::CompanyAssetsService
  def initialize params
    begin
      @params = params.with_indifferent_access
      copy_id = @params['company_assets']['copy_from'].to_i rescue nil
      id = @params['id'].to_i rescue nil
      @company = Company.find_by(id: id) if id
      @default = Company.find_by(id: copy_id) if copy_id
      @email = params["email"]

    rescue Exception => e
      puts e
    end
  end

  def perform
    if @default.present? && @company.present?
      super_user
      copy_profile_fields if @params["company_assets"]['profile_fields'] == '1'
      copy_pending_hires if @params["company_assets"]['pending_hires'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_company_branding') if @params["company_assets"]['company_branding'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_platform_settings') if @params["company_assets"]['platform_settings'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_workflows') if @params["company_assets"]['workflows'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_emails') if @params["company_assets"]['emails'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_company_links') if @params["company_assets"]['company_links'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_workspaces') if @params["company_assets"]['workspaces'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_time_off_policies') if @params["company_assets"]['time_off'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_reports') if @params["company_assets"]['reports'] == '1'
      SandboxAutomation::CopyIndividualAsset.perform_async(@params, 'copy_documents') if @params["company_assets"]['documents'] == '1'
    end
  end


  def copy_company_branding
    copy_logo if @default.logo.present?
    copy_landing_page_image if @default.landing_page_image.present?
    @company.brand_color = @default.brand_color
    @company.company_video = @default.company_video
    @company.about_section = @default.about_section
    @company.bio = @default.bio
    @company.milestone_section = @default.milestone_section
    @company.values_section = @default.values_section
    @company.welcome_note = @default.welcome_note
    @company.preboarding_note = @default.preboarding_note
    @company.preboard_people_settings = @default.preboard_people_settings
    copy_milestones
    copy_company_values
    copy_gallery_images
    @company.save!
  end

  def copy_platform_settings
    @company.date_format = @default.date_format
    @company.time_zone = @default.time_zone
    @company.timeout_interval = @default.timeout_interval
    @company.default_country = @default.default_country
    @company.default_currency = @default.default_currency
    @company.display_name_format = @default.display_name_format
    @company.otp_required_for_login = @default.otp_required_for_login
    @company.login_type = @default.login_type
    @company.default_email_format = @default.default_email_format
    @company.organization_root_id = @default.organization_root_id
    @company.save!
    copy_gdpr
  end

  def copy_company_links
    @default.company_links.where.not(name: @company.company_links.pluck(:name)).try(:each) do |company_link|
      attributes = company_link.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'location_filters', 'team_filters', 'status_filters')
      attributes.merge!({"location_filters": get_location_filters(company_link.location_filters), "team_filters": get_team_filters(company_link.team_filters), "status_filters": get_status_filters(company_link.status_filters)})
      @company.company_links.create(attributes)
    end
  end

  def copy_workflows
    @default.workstreams.find_each do |w|
      unless w.name == 'Custom Tasks'
        begin
          workstream = @company.workstreams.create!(name: w.name, position: w.position, meta: {"team_id"=> get_team_filters(w.meta['team_id']), "location_id"=> get_location_filters(w.meta['location_id']), "employee_type"=> get_status_filters(w.meta['employee_type'], true)}, updated_by_id: super_user.id)
          w.tasks.where.not(task_type: 'jira').where.not(task_type: 'service_now').find_each do |t|
            begin  
              params_hash = {}
              if t.survey_id.present?
                params_hash = {survey_id: t.survey_id}
              elsif t.task_type == "workspace"
                workspace_id = @company.workspaces.where(name: t.workspace&.name).try(:first).try(:id) 
                params_hash = {workspace_id: workspace_id} if workspace_id.present?
              elsif ['coworker', 'owner'].include?(t.task_type)
                params_hash = {task_type: Task.task_types[:hire]} unless super_user
              end
              new_task = create_tasks(t, workstream , params_hash)
              t.attachments.try(:each) do |attachment|
                UploadedFile.create!(entity_id: new_task.id, entity_type: "Task", type: "UploadedFile::Attachment", original_filename: attachment.original_filename, file: attachment.file) rescue nil
              end
            rescue Exception => e
              create_logging('Copy Workflow Task', {task_id: t.id, error: e.message})
            end
          end
          set_workstreams_process_types(w, workstream)
        rescue Exception => e
          create_logging('Copy Workflow', {workstream_name: w.try(:name), error: e.message})
        end
      end
    end
  end

  def create_tasks task , workstream, params_hash={} 
    params = {name: task.name, description: task.description, task_type: task.task_type, position: task.position, deadline_in: task.deadline_in}.merge(params_hash)
    params[:owner_id] = super_user.id if super_user
    new_task = workstream.tasks.create!(params)
    begin
      copy_user_tasks(task.task_user_connections, new_task) if task.task_user_connections.present? && new_task.present?
    rescue Exception => e
      create_logging('Copy Task User Connection', {task_id: new_task.try(:id), error: e.message})
    end
  end

  def copy_user_tasks user_tasks, new_task
    user_tasks.find_each do |user_task|
      new_user = find_new_user(user_task.user) if user_task.user.present?
      new_task.task_user_connections.create(user_id: new_user.id, owner_id: new_user.id, due_date: user_task.try(:due_date), from_due_date: user_task.try(:from_due_date), before_due_date: user_task.try(:before_due_date), schedule_days_gap: user_task.try(:schedule_days_gap)) if new_user.present? && new_task.task_user_connections.where(user_id: new_user.id).blank?
    end
  end

  def copy_emails
    except_email_types = ["new_buddy", "new_manager", "manager_form", "preboarding", "new_activites_assigned", "new_manager_form", "document_completion", "onboarding_activity_notification", "transition_activity_notification", "offboarding_activity_notification", "new_pending_hire", "start_date_change", "invite_user", "new_buddy", "new_manager", "manager_form", "preboarding", "new_activites_assigned", "new_manager_form", "document_completion", "onboarding_activity_notification", "transition_activity_notification", "offboarding_activity_notification", "new_pending_hire", "start_date_change", "invite_user"]
    @default.email_templates.where.not(email_type: except_email_types).find_each do |e|
      attributes = e.attributes.slice('subject', 'cc', 'bcc', 'description', 'email_type', 'email_to', 'name', 'invite_in', 'invite_date', 'schedule_options', 'is_temporary', 'meta')
      l_ids, d_ids, s_ids = get_location_filters(e.location_ids), get_team_filters(e.department_ids), get_status_filters(e.status_ids, true)
      attributes["meta"] = {
        "team_id" => d_ids,
        "location_id" => l_ids,
        "employee_type" => s_ids
      }
      attributes.merge!({ editor_id: super_user.id, permission_type: "permission_group", permission_group_ids: ["all"] })
      email_template = @company.email_templates.create!(attributes) rescue nil 
      e.attachments.try(:each) do |attachment|
        UploadedFile.create!(entity_id: email_template.id, entity_type: "EmailTemplate", type: "UploadedFile::Attachment", original_filename: attachment.original_filename, file: attachment.file) rescue nil
      end
    end
    @company.include_activities_in_email = @default.include_activities_in_email
    @company.send_notification_before_start = @default.send_notification_before_start
    @company.overdue_notification = @default.overdue_notification
    @company.sender_name = @default.sender_name
    @company.save!
  end

  def copy_workspaces
    @default.workspaces.where.not(name: @company.workspaces.pluck(:name)).try(:each) do |workspace|
      new_workspace = @company.workspaces.create!(workspace.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'created_by').merge({created_by: super_user.id})) rescue nil
      next if new_workspace.nil?
      workstream = @company.workstreams.where(name: 'Custom Tasks').first
      workstream.update(process_type_id: @company.process_types.where(name: 'Other').first.id) if workstream.process_type_id.nil?
      workspace.tasks.try(:each) do |task|
        new_task = new_workspace.tasks.create(task.attributes.except('id', 'workspace_id', 'created_at', 'updated_at', 'workstream_id').merge({'workstream_id': workstream.id}))
        task.attachments.try(:each) do |attachment|
          UploadedFile.create!(entity_id: new_task.id, entity_type: "Task", type: "UploadedFile::Attachment", original_filename: attachment.original_filename, file: attachment.file) rescue nil
        end
      end if workstream.present?
    end
  end

  def copy_time_off_policies
    @company.update(enabled_time_off: true)
    @default.pto_policies.try(:each) do |pto_policy|
      new_pto_policy = @company.pto_policies.create!(pto_policy.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'filter_policy_by', 'updated_by_id').merge({updated_by_id: super_user.id, filter_policy_by: {location: get_location_filters(pto_policy.filter_policy_by['location']), teams: get_team_filters(pto_policy.filter_policy_by['teams']), employee_status: get_status_filters(pto_policy.filter_policy_by['employee_status'])}}))
      pto_policy.policy_tenureships.try(:each) do |tenureship|
        new_pto_policy.policy_tenureships.create!(tenureship.attributes.except('id', 'company_id', 'created_at', 'updated_at'))
      end
      pto_policy.approval_chains.order(:created_at).try(:each) do |approval_chain|
        approval_chain_attributes = approval_chain.attributes.except('id', 'company_id', 'created_at', 'updated_at')
        approval_chain_attributes['approval_ids'] = ['all'] if approval_chain_attributes['approval_type'] == 'permission'
        approval_chain_attributes['approval_ids'] = [super_user.id] if approval_chain_attributes['approval_type'] == 'person'
        new_pto_policy.approval_chains.create!(approval_chain_attributes)
      end
      TimeOff::AssignPtoPolicyToUsersJob.perform_in(5.second, {policy: new_pto_policy.id}) if new_pto_policy.is_enabled
    end
  end

  def copy_reports
    @default.reports.try(:each) do |report|
      keys = ["id", "first_name", "last_name", "full_name", "preferred_name", "preferred_full_name", "display_name_format", "title", "location_name", "email", "team_name", "picture", "personal_email"]
      meta = report.meta
      meta['permission_groups'] = @company.user_roles.where(name: @default.user_roles.where(id: meta['permission_groups']).pluck(:name)).ids if meta['recipient_type'] == 'roles' && meta['permission_groups'].exclude?('all')
      meta['individuals'] = [super_user.attributes.select {|k, v| keys.include?(k)}] if meta['recipient_type'] == 'users'
      meta["pto_policy"] = "all_pto_policies" if report.report_type == "time_off"
      if report.report_type == "workflow"
        meta['task_ids'] = []
        meta['tasks_positions'] = []
        meta['tasks_ids'] = tasks_ids_copy(meta['tasks_ids']) if meta['tasks_ids'].present?
      end
      meta['team_id'] = get_team_filters(meta['team_id'])
      meta['location_id'] = get_location_filters(meta['location_id'])
      meta['employee_type'] = meta['employee_type'] == 'all_employee_status' ? 'all_employee_status' : get_status_filters(meta['employee_type'])
      attributes = report.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'last_view', 'user_id')
      attributes['user_role_ids'] = @company.user_roles.where(name: @default.user_roles.where(id: report.user_role_ids).pluck(:name)).ids
      attributes['custom_tables'] =  [] if @company.is_using_custom_table.blank?
      attributes['meta'] = meta
      new_report = @company.reports.create!(attributes.merge({'user_id': super_user.id}))
      copy_reports_custom_fields(report , new_report) if new_report.present?
    end
  end

  def copy_reports_custom_fields report, new_report
    report.custom_field_reports.try(:each) do |custom_field_report|
      custom_field = custom_field_report.custom_field
      new_report_custom_field = @company.custom_fields.find_by(name: custom_field.name) if custom_field.present?
      new_custom_filed_report = new_report.custom_field_reports.create!(custom_field_id: new_report_custom_field.id, position: custom_field_report.position) if new_report_custom_field.present?
    end
  end

  def tasks_ids_copy ids
    tasks, new_ids = Task.all, []
    ids.each do |id|
      task = tasks.find_by_id(id)
      workstream_name = task.workstream.name if task.present?
      workstream = @company.workstreams.where(name: workstream_name).try(:first) if workstream_name.present?
      task_id = workstream.tasks.where(name: task.name).try(:first).try(:id) if workstream.present?
      new_ids << task_id  if task_id.present?
    end
    new_ids
  end

  def copy_profile_fields
    copy_custom_tables
    copy_custom_fields
    copy_default_profile_fields
    copy_profile_templates
    copy_users_and_information if @params["company_assets"]['user_profiles'] == '1'
  end

  def copy_documents
    document_upload_request_mapping, paperwork_template_mapping, paperwork_packet_mapping, document_connection_mapping = {}, {}, {}, {}
    @default.documents.joins(:paperwork_template).try(:each) do |document|
      attributes = document.attributes.except('id', 'company_id', 'created_at', 'updated_at')
      attributes['meta'] = {"type"=>attributes['meta']['type'], "team_id"=> get_team_filters(attributes['meta']['team_id']), "location_id"=> get_location_filters(attributes['meta']['location_id']), "employee_type"=> get_status_filters(attributes['meta']['employee_type'], true)}
      new_document = @company.documents.create(attributes)
      attached_file = document.attached_file
      UploadedFile.create!(entity_id: new_document.id, entity_type: "Document", type: "UploadedFile::DocumentFile", original_filename: attached_file.original_filename, file: attached_file.file, skip_scanning: true) if attached_file.present?
      paperwork_template = document.paperwork_template
      begin
        new_paperwork = @company.paperwork_templates.create!(paperwork_template.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'document_id', 'user_id', 'state').merge({'document_id': new_document.id, 'user_id': super_user.id, 'skip_callback': true, 'state': 'draft'}))
        paperwork_template_mapping.merge!({"#{paperwork_template.id}": new_paperwork.id}) if new_paperwork.present?
        HellosignCall.update_template_files(new_paperwork.id, @company.id, super_user.id)
      rescue Exception => e
        create_logging('Copy Document', {document_id: document.id, error: e.message})
      end
    end

    @default.document_upload_requests.joins(:document_connection_relation).try(:each) do |document_upload_request|
      document_connection = DocumentConnectionRelation.create!(document_upload_request.document_connection_relation.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'document_id'))
      attributes = document_upload_request.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'user_id', 'document_connection_relation_id')
      if attributes['meta'].present?
        attributes['meta'] = {"type"=>attributes['meta']['type'], "team_id"=>get_team_filters(attributes['meta']['team_id']), "location_id"=>get_location_filters(attributes['meta']['location_id']), "employee_type"=>get_status_filters(attributes['meta']['employee_type'], true)}
      end
      new_document = @company.document_upload_requests.create!(attributes.merge({'document_connection_relation_id': document_connection.id, 'user_id': super_user.id}))
      document_upload_request_mapping.merge!({"#{document_upload_request.id}": new_document.id}) if new_document.present?
      document_connection_mapping.merge!({"#{document_upload_request.document_connection_relation.id}": document_connection.id}) if document_connection.present?
    end

    @default.paperwork_packets.try(:each) do |paperwork_packet|
      attributes = paperwork_packet.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'user_id')
      if attributes['meta'].present?
        attributes['meta'] = {"type"=>attributes['meta']['type'], "team_id"=>get_team_filters(attributes['meta']['team_id']), "location_id"=>get_location_filters(attributes['meta']['location_id']), "employee_type"=>get_status_filters(attributes['meta']['employee_type'], true)}
      end
      new_paperwork_packet = @company.paperwork_packets.create!(attributes.merge({'user_id': super_user.id}))
      paperwork_packet_mapping.merge!({"#{paperwork_packet.id}": [new_paperwork_packet.id, document_token_generator]}) if new_paperwork_packet.present?
      paperwork_packet.paperwork_packet_connections.try(:each) do |connection|
        connectable_id = connection.connectable_type == 'PaperworkTemplate' ? paperwork_template_mapping[:"#{connection.connectable_id}"] : document_upload_request_mapping[:"#{connection.connectable_id}"]
        new_paperwork_packet.paperwork_packet_connections.create(connection.attributes.except('id', 'connectable_id', 'created_at', 'updated_at').merge({'connectable_id': connectable_id})) if connectable_id
      end
    end
    begin
      copy_user_document_connections(document_connection_mapping, paperwork_packet_mapping)
    rescue Exception => e
      puts e
    end
  end

  def copy_user_document_connections document_connection_mapping, paperwork_packet_mapping
    user_connections = UserDocumentConnection.where(company_id: @default.id)
    user_connections.try(:find_each) do |user_document_connection|
      new_user = find_new_user(user_document_connection.user) if user_document_connection.user.present?
      if new_user.present?
        new_created_by = find_new_user(user_document_connection.created_by) if user_document_connection.created_by.present?
        document_connection_relation_id = document_connection_mapping[:"#{user_document_connection.document_connection_relation_id}"]
        if user_document_connection.packet_id.present?
          packet_document_token = paperwork_packet_mapping[:"#{user_document_connection.packet_id}"]
          packet_id = packet_document_token[0]
          document_token = packet_document_token[1]
        else
          document_token = document_token_generator
          packet_id = nil
        end
        UserDocumentConnection.create(user_id: new_user.id, state: user_document_connection.try(:state), company_id: @company.id, created_by_id: new_created_by.try(:id), due_date: user_document_connection.try(:due_date), packet_id: packet_id, document_token: document_token, document_connection_relation_id: document_connection_relation_id)
      end
    end
  end

  private
  def find_new_user user
    email = user.email || user.personal_email
    if email.present?
      email_prefix = email.split('@')[0]
      email_suffix = email.split('@')[1]
      @company.users.where('email = ? OR personal_email = ?',"#{email_prefix}@#{@company.domain}", "#{email_prefix}+#{@company.id}@#{email_suffix}").try(:first)
    end
  end
  def document_token_generator
    SecureRandom.uuid + "-" + DateTime.now.to_s
  end
  def copy_logo
    begin
      logo = UploadedFile.find_by(entity_id: @default.id, entity_type: "Company", type: "UploadedFile::DisplayLogoImage")
      UploadedFile.create!(entity_id: @company.id, entity_type: "Company", type: "UploadedFile::DisplayLogoImage", original_filename: logo.original_filename, file: logo.file) if logo
    rescue Exception => e
      create_logging('Copy Company Logo', {error: e.message})
    end
  end

  def copy_landing_page_image
    begin
      landing_page_image = UploadedFile.find_by(entity_id: @default.id, entity_type: "Company", type: "UploadedFile::LandingPageImage")
      UploadedFile.create!(entity_id: @company.id, entity_type: "Company", type: "UploadedFile::LandingPageImage", original_filename: landing_page_image.original_filename, file: landing_page_image.file)
    rescue Exception => e
      create_logging('Copy Company Landing Page Image', {error: e.message})
    end
  end

  def copy_milestones
    begin
      @default.milestones.where.not(name: @company.milestones.pluck(:name)).order(:happened_at).try(:each) do |milestone|
        new_milestone = @company.milestones.create(milestone.attributes.except('id', 'company_id', 'created_at', 'updated_at'))
        image = milestone.milestone_image
        UploadedFile.create!(entity_id: new_milestone.id, entity_type: "Milestone", type: "UploadedFile::MilestoneImage", original_filename: image.original_filename, file: image.file) if image.present?
      end
    rescue Exception => e
      create_logging('Copy Company Milestone', {error: e.message})
    end
  end

  def copy_company_values
    begin
      @default.company_values.where.not(name: @company.company_values.pluck(:name)).order(:id).try(:each) do |company_value|
        new_company_value = @company.company_values.create(company_value.attributes.except('id', 'company_id', 'created_at', 'updated_at'))
        image = company_value.company_value_image
        UploadedFile.create!(entity_id: new_company_value.id, entity_type: "CompanyValue", type: "UploadedFile::CompanyValueImage", original_filename: image.original_filename, file: image.file) if image.present?
      end
    rescue Exception => e
      create_logging('Copy Company Values', {error: e.message})
    end
  end


  def copy_gallery_images
    begin
      @default.gallery_images.where.not(original_filename: @company.gallery_images.pluck(:original_filename)).order(:created_at).try(:each) do |gallery_image|
        UploadedFile.create!(entity_id: @company.id, entity_type: "Company", type: "UploadedFile::GalleryImage", original_filename: gallery_image.original_filename, file: gallery_image.file)
      end
    rescue Exception => e
      create_logging('Copy Company GalleryImage', {error: e.message})
    end
  end

  def copy_gdpr
    attributes = @default.general_data_protection_regulation.attributes.except('id', 'company_id', 'last_edited_by') if @default.general_data_protection_regulation.present?
    if attributes.present?
      @company.general_data_protection_regulation.destroy if @company.general_data_protection_regulation.present?
      GeneralDataProtectionRegulation.create(attributes.merge({"company_id": @company.id}))
    end
  end

  def create_super_user
    begin
      super_user = @company.users.create!(
        first_name: 'Super',
        last_name: 'User',
        email: "super_user@#{@company.domain}",
        password: 'super123!',
        personal_email: "super_user.personal@#{@company.domain}",
        title: 'Super User',
        role: :account_owner,
        state: :active,
        current_stage: :registered,
        start_date: 31.days.ago,
        super_user: true
      )

      super_user.create_profile!
    rescue Exception => e
      puts e
    end
  end

  def set_workstreams_process_types copy_workstream, workstream
    process_type_name = copy_workstream.process_type.name if copy_workstream.process_type
    if process_type_name
      id = @company.process_types.where(name: process_type_name, company_id: @company.id).first.id
      workstream.update(process_type_id: id)
    else
      id = @company.process_types.where(name: 'Other', company_id: @company.id).first.id
      workstream.update(process_type_id: id)
    end
  end

  def copy_custom_tables
    if @default.is_using_custom_table
      if @company.is_using_custom_table.blank?
        @company.update(is_using_custom_table: true)
        @company.create_default_custom_tables(@company)
      end
      @default.custom_tables.where.not(name: @company.custom_tables.pluck(:name)).each do |custom_table|
        begin
          new_custom_table = @company.custom_tables.create!(custom_table.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'is_approval_required'))
          if custom_table.is_approval_required
            custom_table.approval_chains.try(:each) do |approval_chain|
              approval_chain_attributes = approval_chain.attributes.except('id', 'company_id', 'created_at', 'updated_at')
              approval_chain_attributes['approval_ids'] = ['all'] if approval_chain_attributes['approval_type'] == 'permission'
              approval_chain_attributes['approval_ids'] = [super_user.id] if approval_chain_attributes['approval_type'] == 'person'
              new_custom_table.approval_chains.create!(approval_chain_attributes)
            end
            new_custom_table.update(is_approval_required: custom_table.is_approval_required)
          end
        rescue Exception => e
          create_logging('Copy Custom Table', {custom_table: custom_table.id, error: e.message})
        end

      end
    end
  end

  def copy_custom_fields
    created_fields = []
    @default.custom_fields.where.not(name: @company.custom_fields.pluck(:name)).try(:each) do |custom_field|
      unless created_fields.include?(custom_field.name)
        begin
          attributes = custom_field.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'api_field_id')
          attributes['custom_table_id'] = @company.custom_tables.find_by(name: custom_field.custom_table.name).id if custom_field.custom_table.present?
          attributes['custom_section_id'] = @company.custom_sections.find_by(section: custom_field.custom_section.section).id if custom_field.custom_section.present?
          
          new_custom_field = @company.custom_fields.create!(attributes) rescue nil
          created_fields << new_custom_field.name if new_custom_field.present?
          custom_field.custom_field_options.try(:each) do |custom_field_option|
            new_custom_field.custom_field_options.create(custom_field_option.attributes.except('id', 'custom_field_id', 'created_at', 'updated_at')) rescue nil
          end

          custom_field.sub_custom_fields.try(:each) do |sub_custom_field|
            new_custom_field.sub_custom_fields.create(sub_custom_field.attributes.except('id', 'custom_field_id', 'created_at', 'updated_at')) rescue nil
          end
        rescue Exception => e
          create_logging('Copy Custom Fields', {custom_field: custom_field.id, error: e.message}) 
        end  
      end
    end
  end

  def copy_profile_templates
    @default.profile_templates.where.not(name: @company.profile_templates.pluck(:name)).try(:each) do |template|
      begin
        new_template = @company.profile_templates.find_or_create_by(template.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'edited_by_id', 'meta').merge({'edited_by_id': super_user.id,'meta':  {"team_id"=> get_team_filters(template.meta['team_id']), "location_id"=> get_location_filters(template.meta['location_id']), "employee_type"=> get_status_filters(template.meta['employee_type'], true)}}))
        set_workstreams_process_types(template, new_template)
        template.profile_template_custom_field_connections.try(:each) do |connection|
          attributes = connection.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'profile_template_id')
          custom_fields = @company.custom_fields.where(name: connection.custom_field.name) if connection.custom_field_id.present?
          if custom_fields.present? && custom_fields.count > 1
            custom_fields.each do |custom_field|
              attributes['custom_field_id'] = custom_field.id if connection.custom_field_id.present?
              new_field = new_template.profile_template_custom_field_connections.create(attributes)
              break if new_field.id.present?
            end
          else     
            attributes['custom_field_id'] = custom_fields.first.id if custom_fields.present?
            new_template.profile_template_custom_field_connections.create(attributes) rescue nil
          end
        end
        template.profile_template_custom_table_connections.try(:each) do |connection|
          attributes = connection.attributes.except('id', 'company_id', 'created_at', 'updated_at', 'profile_template_id')
          attributes['custom_table_id'] = @company.custom_tables.find_by(name: connection.custom_table.name).id
          new_template.profile_template_custom_table_connections.create(attributes) rescue nil
        end
      rescue Exception => e
        create_logging('Copy Profile Template', {profile_template: template.id, error: e.message})
      end
    end
  end

  def copy_default_profile_fields
    begin
      company_fields = @company.prefrences['default_fields'].map { |f| f['name'] if f['profile_setup'] == 'profile_fields' }
      default_fields = @default.prefrences['default_fields'].select do |f| 
        f['profile_setup'] == 'profile_fields' && !company_fields.include?(f['name']) rescue false
      end

      default_fields.try(:each){ |field| @company.prefrences['default_fields'].push(field) }
      @company.save!
    rescue Exception => e
      create_logging('Copy default field', {error: e.message})
    end
  end

  def super_user
    @super_user ||= @company.users.find_by(super_user: true) || @company.users.where('email = ? OR personal_email = ?',"super_user@#{@company.domain}","super_user.personal@#{@company.domain}").first || create_super_user
  end

  def get_location_filters filters
    return filters if filters == ['all'] || filters.nil?
    location_filters = []
    filters.each do |loc|
      location = @default.locations.find_by(id: loc.to_i)
      new_location = @company.locations.find_or_create_by(name: location.name) if location
      location_filters.push(new_location.id) if new_location
    end
    location_filters
  end

  def get_team_filters filters
    return filters if filters == ['all'] || filters.nil?
    team_filters = []
    filters.each do |team|
      team = @default.teams.find_by(id: team)
      new_team = @company.teams.find_or_create_by(name: team.name) if team
      team_filters.push(new_team.id) if new_team
    end
    team_filters
  end

  def get_status_filters filters, add_id=nil
    return ['all'] if filters == ['all'] || filters.nil?
    status_filters = []
    filters.each do |status|
      if status == ''
        status_filters.push(status)
        next
      end
      employee_status = @company.custom_fields.where(field_type: 13).take
      status = @default.custom_fields.where(field_type: 13).take.custom_field_options.find(status).option if add_id && status.present?
      new_status = employee_status.custom_field_options.find_or_create_by(option: status)
      status_filters.push(status) if new_status && add_id.nil?
      status_filters.push(new_status.id) if new_status && add_id.present?
    end
    status_filters
  end

  def copy_users_and_information users=nil
    coworker_field_values = []
    manager_values = []
    buddy_values = []
    pending_coworker_cs = []
    fifteen_five_users = []
    users = @default.users if users.nil?
    users.each do |user|
      begin
        params = set_user_information(user)
        id = @company.users.where('email = ? OR personal_email = ?', params[:email], params[:personal_email]).first.try(:id)
        form = UserForm.new(params.merge({id: id}))
        form.save!
        new_user = form.user
        image = user.profile_image
        UploadedFile.create!(entity_id: new_user.id, entity_type: "User", type: "UploadedFile::ProfileImage", original_filename: image.original_filename, file: image.file) if image.present?
        new_user.build_profile(user.profile.attributes.except('id', 'created_at', 'user_id')).save!
        coworker_field_values = coworker_field_values + copy_custom_field_values(user, new_user)
        manager_values << [user.manager, new_user] if user.manager.present?
        buddy_values << [user.buddy, new_user] if user.buddy.present?
        pending_coworker_cs = pending_coworker_cs +  copy_custom_tables_data(user, new_user) if @company.is_using_custom_table && @default.is_using_custom_table
        fifteen_five_users << new_user.id if user.fifteen_five_id.present?
      rescue Exception => e
        create_logging('Copying User', {user_id: user.id, error: e.message})
      end
    end
    assign_coworker_field_values(coworker_field_values) if coworker_field_values.count > 0
    assign_managers(manager_values) if manager_values.count > 0
    assign_buddies(buddy_values) if buddy_values.count > 0
    update_pending_coworker_cs(pending_coworker_cs)
    add_performance_tab(fifteen_five_users)
    set_organization_root
  end

  def set_organization_root
    @company.update(organization_root_id: @company.users.find_by(first_name: 'Jenna', last_name: 'Fischer').try(:id))
  end

  def copy_pending_hires
    @default.pending_hires.try(:each) do |ph|
      params = ph.attributes.except('id', 'created_at', 'updated_at', 'user_id', 'manager_id', 'location_id', 'team_id', 'personal_email')
      @company.pending_hires.create!(pending_hire_params(ph, params))
      copy_users_and_information([ph.user]) if ph.user.present?
    end
  end

  def pending_hire_params ph, params
    params.merge({company_id: @company.id,
         team_id: ph.team.present? ? @company.teams.find_or_create_by(name: ph.team.name).id : nil ,
         location_id: ph.location.present? ? @company.locations.find_or_create_by(name: ph.location.name).id : nil ,
         manager_id: ph.manager.present? ? get_user_id_by_email(get_coworker_email(ph.manager)) : nil
        })
  end

  def copy_custom_field_values user, new_user
    coworker_field_values = []
    user.custom_field_values.each do |cfv|
      if cfv.sub_custom_field.present?
        sub_field = cfv.sub_custom_field
        CustomFieldValue.set_custom_field_value(new_user, sub_field.custom_field.name, cfv.value_text, sub_field.name, false)
      elsif cfv.custom_field.present?
        if cfv.custom_field.field_type == 'coworker'
          coworker_field_values << [cfv, new_user]
          next
        end
        value_text = ['multiple_choice', 'mcq'].include?(cfv.custom_field.field_type) ? cfv.custom_field_option.try(:option) : cfv.value_text
        value_text = get_check_box_values(cfv) if cfv.custom_field.field_type == 'multi_select'
        CustomFieldValue.set_custom_field_value(new_user, cfv.custom_field.name, value_text)
      end
    end
    return coworker_field_values
  end

  def set_user_information user
    {email: user.email.present? ? user.email.split('@')[0] + '@' + @company.domain : nil,
     company_id: @company.id,
     team_id: user.team.present? ? @company.teams.find_or_create_by(name: user.team.name).id : nil ,
     location_id: user.location.present? ? @company.locations.find_or_create_by(name: user.location.name).id : nil ,
     password: 'Admin@123',
     user_role_id: user.user_role.present? ? @company.user_roles.find_or_create_by(name: user.user_role.name,
     role_type: user.user_role.role_type).id : nil,
     role: user.role,
     start_date: user.start_date,
     title: user.title,
     termination_date: user.termination_date,
     current_stage: user.current_stage,
     first_name: user.first_name,
     last_name: user.last_name,
     preferred_name: user.preferred_name,
     onboard_email: user.onboard_email,
     personal_email: user.personal_email.present? ? user.personal_email.split('@')[0] + "+#{@company.id}@" + user.personal_email.split('@')[1] : nil,
     onboarding_profile_template_id: user.onboarding_profile_template.present? ? @company.profile_templates.find_by(name: user.onboarding_profile_template.try(:name)).try(:id) : nil,
     offboarding_profile_template_id: user.offboarding_profile_template.present? ? @company.profile_templates.find_by(name: user.offboarding_profile_template.try(:name)).try(:id) : nil,
     incomplete_paperwork_count: user.incomplete_paperwork_count, 
     incomplete_upload_request_count: user.incomplete_upload_request_count,
     outstanding_owner_tasks_count: user.outstanding_owner_tasks_count,
     outstanding_tasks_count: user.outstanding_tasks_count,
     user_document_connections_count: user.user_document_connections_count
   }
  end

  def get_check_box_values cfv
    checkbox_values = []
    custom_field = @company.custom_fields.find_by(name: cfv.custom_field.name)
    cfv.checkbox_values.try(:each) do |cv|
      option = cfv.custom_field.custom_field_options.find_by(id: cv).try(:option)
      option_id = custom_field.custom_field_options.find_by(option: option).try(:id) if option
      checkbox_values << option_id if option_id
    end if custom_field
    return checkbox_values
  end

  def get_coworker_email coworker
    coworker.email ? (coworker.email.split('@')[0] + '@' + @company.domain) : coworker.personal_email.split('@')[0] + "+#{@company.id}@" + coworker.personal_email.split('@')[1]
  end

  def get_user_id_by_email email
    @company.users.where('email = ? OR personal_email = ?', email, email).first.try(:id)
  end

  def assign_coworker_field_values cfvs
    cfvs.try(:each) do |entry|
      coworker = entry[0].coworker
      return if coworker.nil?
      value_text = get_coworker_email(coworker)
      CustomFieldValue.set_custom_field_value(entry[1], entry[0].custom_field.name, value_text)
    end
  end


  def assign_managers values
    values.try(:each) do |entry|
      return if entry[0].nil?
      email = get_coworker_email(entry[0])
      id = get_user_id_by_email(email)
      entry[1].update(manager_id: id) if id.present?
    end
  end

  def assign_buddies values
    values.try(:each) do |entry|
      return if entry[0].nil?
      email = get_coworker_email(entry[0])
      id = get_user_id_by_email(email)
      entry[1].update(buddy_id: id) if id.present?
    end
  end

  def copy_custom_tables_data user, new_user
    pending_coworker_cs = []
    user.custom_table_user_snapshots.includes(:custom_table).try(:each) do |ctus|
      custom_table = @company.custom_tables.find_by(name: ctus.custom_table.name)
      if custom_table
        CustomTableUserSnapshot.bypass_approval = true
        new_ctus = new_user.custom_table_user_snapshots.create!(custom_table_id: custom_table.id, state: ctus.state,
          edited_by_id: super_user.id, effective_date: ctus.effective_date, requester_id: super_user.id, request_state: ctus.request_state,
          integration_type: ctus.integration_type, is_terminated: ctus.is_terminated, terminated_data: ctus.terminated_data, terminate_callback: true, skip_dispatch_email: true, skip_standard_callbacks: true)
        CustomTableUserSnapshot.bypass_approval = false
        ctus.custom_snapshots.try(:each) do |cs|
          custom_field = cs.custom_field
          custom_field_id = nil
          custom_field_value = cs.custom_field_value
          if custom_field.present?
            custom_field_id = custom_table.custom_fields.find_by(name: cs.custom_field.name).try(:id)
            if ['multiple_choice', 'mcq', 'employment_status'].include?(custom_field.field_type)
              custom_field_value = @company.custom_fields.find_by(name: custom_field.name)
              .try(:custom_field_options).find_by(option: custom_field.custom_field_options.find_by(id: custom_field_value.to_i).try(:option)).try(:id).try(:to_s)
            end
          end
          custom_field_value = @company.locations.find_by(name: @default.locations.find_by(id: custom_field_value.to_i).try(:name)).try(:id) if cs.preference_field_id == 'loc'
          custom_field_value = @company.teams.find_by(name: @default.teams.find_by(id: custom_field_value.to_i).try(:name)).try(:id) if cs.preference_field_id == 'dpt'
          new_cs = new_ctus.custom_snapshots.create!(custom_field_id: custom_field_id, custom_field_value: custom_field_value, preference_field_id: cs.preference_field_id)
          pending_coworker_cs << [new_cs, custom_field_value, new_user] if new_cs.present? && custom_field_value.present? && (['man', 'bdy'].include?(cs.preference_field_id) || (custom_field.present? && custom_field.field_type == 'coworker'))
        end
      end
    end
    return pending_coworker_cs
  end

  def update_pending_coworker_cs pending_coworker_cs
    pending_coworker_cs.try(:each) do |entry|
      user = @default.users.find_by(id: entry[1])
      if user
        email = get_coworker_email(user)
        id = get_user_id_by_email(email)
        entry[0].update_column(:custom_field_value,  id)
      end
    end
  end

  def add_performance_tab fifteen_five_users
    create_fifteen_five_integration if @company.pm_integration_type('fifteen_five') != 'fifteen_five'
    @company.users.where(id: fifteen_five_users).each do |user|
      ::IntegrationsService::UserIntegrationOperationsService.new(user, ['fifteen_five']).perform('create') 
    end if @company.pm_integration_type('fifteen_five') == 'fifteen_five'
  end

  def create_fifteen_five_integration
    integration_inventory = IntegrationInventory.find_by_api_identifier('fifteen_five')
    @default.integration_instances.where(api_identifier: 'fifteen_five').find_each do |instance|
      attributes = instance.attributes.except('id', 'created_at', 'updated_at', 'company_id', 'unsync_records_count', 'synced_at')
      new_instance = @company.integration_instances.create!(attributes)
      ['Subdomain',  'Access Token'].each do |col|
        configuration = integration_inventory.integration_configurations.find_by(field_name: col)
        val = col == 'Subdomain' ? 'my.staging' : ENV['FIFTEEN_FIVE_SANDBOXES_ACCESS_TOKEN']
        attributes = { value: val, name: col, integration_configuration_id: configuration.id }
        new_instance.integration_credentials.where(integration_configuration_id: configuration.id).first_or_create(attributes)
      end
    end
  end

  def create_logging(action, params)
    (@logging ||= LoggingService::GeneralLogging.new).create(@company, action, params)
  end

end
