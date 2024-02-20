require 'sendgrid-ruby'
class SendGridEmailService
  include SendGrid
  def initialize(template_obj)
    @template_obj = template_obj
    @mail = Mail.new
    @personalization = Personalization.new
    if template_obj
      company_id = template_obj[:company]
      @admin_user = ['admin_email', 'reset_password'].include?(@template_obj[:email_type])
      @company = Company.find_by(id: company_id) if company_id
      @emails_to = template_obj[:emails_to]
      @emails_cc = template_obj[:emails_cc]
      @emails_bcc = template_obj[:emails_bcc]
      @template_id = template_obj[:template_id]
      @attachments = template_obj[:email_attachments]
      user_id = template_obj[:user]
      @user = User.find_by(id: user_id) if user_id
      @email_reply = template_obj[:email_from]
      @sanitized_description = template_obj[:description]
      @description = template_obj[:description]
      @email_subject = template_obj[:email_subject]
      filter_email_subject if @email_subject
      @email_title = template_obj[:email_title]
      @email_button = template_obj[:email_button]
      @button_link = template_obj[:button_link]
      @task_name = template_obj[:task_name]
      @message_type = template_obj[:message_type]
      @message_sender = template_obj[:message_sender]
      @message = template_obj[:message]
      @user_avatar_url = @user.picture if @user.present?
      @user_avatar_url = template_obj[:user_avatar_url] if template_obj[:user_avatar_url]
      @sapling_login = template_obj[:sapling_login]
      @pto_email = template_obj[:pto_email]
      @bulk_email_data = template_obj[:bulk_email_data] if template_obj[:bulk_email_data]
      @report_filename = template_obj[:report_filename]
      @report_file = template_obj[:report_file]
      @skip_scanning = template_obj[:skip_scanning].present? ? true : false
      @document_zip_file = template_obj[:completed_documents_zip_file]
      @document_zip_filename = template_obj[:completed_documents_zip_filename]
      set_digest_email_variables(template_obj) if template_obj[:digest_email]
      set_pto_email_variables template_obj if @pto_email
      add_new_hires_email_data(template_obj) if template_obj[:email_type] == "new_hires"
      set_weekly_metrices_email_variables(template_obj) if template_obj[:email_type] == 'weekly_metrics'
      set_upload_feedback_email_variables(template_obj) if template_obj[:email_type] == 'upload_feedback'
      set_ct_approval_denial_variables(template_obj) if template_obj[:email_type] == 'ct_approval_denial'
      @content_description = template_obj[:content] if template_obj[:content]
      set_document_failure_variables(template_obj) if template_obj[:email_type] == 'document_failure'
      set_document_packet_assignment_variables(template_obj) if template_obj[:email_type] == 'document_packet_assignment'
      set_integration_failure_variables(template_obj) if template_obj[:email_type] == 'integration_failure'
      @sandbox_invite_email = template_obj[:sandbox_invite_email]
      set_sandbox_invite_email(template_obj) if @sandbox_invite_email
      set_document_flipped_email(template_obj) if template_obj[:email_type] == 'document_flipped_email'
    end
  end

  def perform
    notification_settings = @company&.notifications_enabled || ['reset_password', 'invite_user'].include?(@template_obj[:email_type])
    if (@company&.account_state == 'active' && notification_settings) || @admin_user
      create_email
      @response
    end
  end

  private

  def create_email
    begin
      if @admin_user
        @mail.from = Email.new(email: @email_reply)
      else
        @company.sender_name ? sender = @company.sender_name : sender = @company.subdomain
        sender_email = from_email(@company)
        @mail.from = Email.new(email: sender_email, name: sender)
        if @email_reply.present?
          name_and_email = @email_reply.split('(')
          reply_to_email = name_and_email.last.gsub('(','').gsub(')', '')
          reply_to_name =  name_and_email.present? && name_and_email[0].present? && name_and_email.first.strip.downcase == 'sapling' ? "#{name_and_email[0] rescue '' }" : "#{name_and_email.first.strip}"
          @mail.reply_to = Email.new(email: reply_to_email, name: reply_to_name)
        end
      end
      add_emails_to if @emails_to
      return if @personalization.tos.blank?
      add_emails_cc if @emails_cc
      add_emails_bcc if @emails_bcc
      @mail.personalizations = @personalization
      @mail.template_id = @template_id
      add_attachments if @attachments
      add_report_file if @report_filename
      add_document_zip_file if @document_zip_filename
      filter_description if @description
      add_defective_users_file if @defective_users_filename
      if @pto_email
        create_pto_email_body
      elsif @digest_email
        create_digest_email_body
      elsif @metrics_email
        create_metrics_email_body
      elsif @bulk_email_data.present?
        create_sarah_bulk_onboarding_body
      elsif @upload_feedback_email
        create_upload_feedback_body
      elsif @custom_table_email.present?
        create_custom_table_email_body
      elsif @document_failure_email.present?
        create_document_failure_email_body
      elsif @document_packet_assignment_email
        create_document_packet_assignment_email_body
      elsif @integrtation_failure_email.present?
        create_integration_failure_email_body
      elsif @sandbox_invite_email
        create_sandbox_invite_email_body
      elsif @document_flipped_email.present?
        create_document_flipped_email_body
      else
        create_email_body
      end
      send_email
      store_sendgrid_email
    rescue Exception=>e
      logging.create(@company, 'Create Email', {result: 'Failed to create email', error: e.message, template_id: @template_id }, 'Email')
    end
  end

  def sandbox_trial_remaining email
    user = @company.users.where('email = ? OR personal_email = ?', email, email).first if @company.present?
    return true if user.blank? or !@company.sandbox_trial_applicable
    user.user_sandbox_trial_available
  end

  def company_trial_remaining
    @company.present? && @company.company_trial_applicable ? @company.billing.trial_end_date > Time.now() : true 
  end

  def add_emails_to
    if @emails_to.is_a?(String)
      @personalization.to = Email.new(email: @emails_to) if sandbox_trial_remaining(@emails_to) && company_trial_remaining
    else
      @emails_to.uniq.each do |email|
        @personalization.to = Email.new(email: email) if sandbox_trial_remaining(email) && company_trial_remaining
      end
    end
  end

  def add_emails_cc
    if @emails_cc.is_a?(String)
      @personalization.cc = Email.new(email: @emails_cc) if sandbox_trial_remaining(@emails_cc) && company_trial_remaining
    else
      @emails_cc.uniq.each do |email|
        @personalization.cc = Email.new(email: email) if sandbox_trial_remaining(email) && company_trial_remaining
      end
    end
  end

  def add_emails_bcc
    if @emails_bcc.is_a?(String)
      @personalization.bcc = Email.new(email: @emails_bcc) if sandbox_trial_remaining(@emails_bcc) && company_trial_remaining
    else
      @emails_bcc.uniq.each do |email|
        @personalization.bcc = Email.new(email: email) if sandbox_trial_remaining(email) && company_trial_remaining
      end
    end
  end

  def add_attachments
    @attachments.each do |file, index|
      file_object = UploadedFile.find(file[:id])
      attachment = Attachment.new
      if Rails.env.development?
        attachment.content = Base64.strict_encode64(File.open("#{Rails.root}/public/" + file_object.file.url, 'rb').read)
      else
        attachment.content = Base64.strict_encode64(file_object.file.read)
      end
      attachment.type = file_object.type
      attachment.filename = file_object['original_filename']
      attachment.disposition = 'attachment'
      @mail.attachments = attachment
    end if @attachments
  end

  def add_report_file
    if @report_filename
      attachment = Attachment.new
      file = File.open(@report_file, 'rb')
      attachment.content = Base64.strict_encode64(File.read(@report_file))
      attachment.type = "file"
      attachment.filename = @report_filename
      attachment.disposition = 'attachment'
      @mail.attachments = attachment
    end
  end

  def add_document_zip_file
    if @document_zip_filename
      attachment = Attachment.new
      file = File.open(@document_zip_file, 'rb')
      attachment.content = Base64.strict_encode64(File.read(@document_zip_file))
      attachment.type = "file"
      attachment.filename = @document_zip_filename
      attachment.disposition = 'attachment'
      @mail.attachments = attachment
    end
  end

  def add_defective_users_file
    if @defective_users_filename
      attachment = Attachment.new
      file = File.open(@defective_users_file, 'rb')
      attachment.content = Base64.strict_encode64(File.read(@defective_users_file))
      attachment.type = "file"
      attachment.filename = @defective_users_filename
      attachment.disposition = 'attachment'
      @mail.attachments = attachment
    end
  end

  def filter_email_subject
    @email_subject = @email_subject.gsub('<br>', ' ')
    @email_subject = @email_subject.gsub('&lt;br&gt;', ' ')
  end

  def filter_description
    @description = @description.gsub('<p><br></p>', '<br>')
    @description = @description.gsub('&lt;br&gt;', '<br>')
    @description = @description.gsub('<h1', '<h1 style="margin: 0px;"')
    @description = @description.gsub('<h2', '<h2 style="margin: 0px;"')
    @description = @description.gsub('<h3', '<h3 style="margin: 0px;"')
    @description = @description.gsub('</p', '</div')
    @description = @description.gsub('<p', '<div')
    @description = @description.gsub(/\t/, '&nbsp;')
    @sanitized_description = @description
    @description = @description.gsub('&#111;&#114;', 'or')
    @description = @description.gsub('&#111;&#82;', 'oR')
    @description = @description.gsub('&#79;&#82;', 'OR')
    @description = @description.gsub('&#79;&#114;', 'Or')
    @description = @description.gsub('&#97;&#110;&#100;', 'and')
    @description = @description.gsub('&#97;&#78;&#100;', 'aNd')
    @description = @description.gsub('&#97;&#110;&#68;', 'anD')
    @description = @description.gsub('&#97;&#78;&#68;', 'aND')
    @description = @description.gsub('&#65;&#78;&#68;', 'AND')
    @description = @description.gsub('&#65;&#110;&#68;', 'AnD')
    @description = @description.gsub('&#65;&#78;&#100;', 'ANd')
    @description = @description.gsub('&#65;&#110;&#100;', 'And')
  end

  def count_instances(string, substring)
    string.each_char.each_cons(substring.size).map(&:join).count(substring)
  end

  def create_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'email_title': @email_title,
      'content': @description,
      'subject': @email_subject,
      'button_url': @button_link,
      'customer_brand': @company&.email_color || '#1A1A33',
      'button_cta': @email_button,
      'customer_logo': @company&.logo,
      'full_name': @user.present? ? @user.full_name : '',
      'user_avatar_url': @user_avatar_url,
      'task_name': @task_name,
      'message_type': @message_type,
      'message_sender': @message_sender,
      'message': @message,
      'sapling_login': @sapling_login,
      'new_hires': @new_hires,
      'admin_view': @admin_view,
      'disable_url': @disable_url
    }
    @body['categories'] = @categories
  end

  def create_sarah_bulk_onboarding_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'subject': @email_subject,
      'email_data': @bulk_email_data
    }
  end

  def create_pto_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'email_title': @email_title,
      'subject': @email_subject,
      'customer_brand': @company&.email_color || '#1a1a33',
      'customer_logo': @company.logo,
      'full_name': @user.present? ? @user.full_name : '',
      'user_avatar_url': @user_avatar_url,
      'user_initials': @user.initials,
      'pto_date': @pto_date,
      'pto_type': @pto_type,
      'pto_length': @pto_length,
      'leftover_balance': @leftover_balance,
      'pto_comment': @pto_comment,
      'button_cta': @button_cta,
      'review_details_url': @review_details_url,
      'button_secondary_cta': @button_secondary_cta,
      'sapling_link': @sapling_link,
      'out_of_office': @out_of_office,
      'show_approve_deny': @show_approve_deny,
      'nick_approved_denied': @nick_approved_denied,
      'approved': @approved,
      'manager_name': @manager_name,
      'policy_name': @policy_name
    }
  end

  def create_custom_table_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'email_title': @email_title,
      'subject': @email_subject,
      'customer_brand': @company&.email_color || '#1a1a33',
      'customer_logo': @company.logo,
      'requester_name': @requester_name,
      'user_name': @user_name,
      'table_name': @table_name,
      'ctus_date': @ctus_date,
      'approvers': @approvers,
      'denied_email': @denied_email,
      'action': @action,
      'button_url': @button_link
    }
  end

  def create_document_failure_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'subject': @email_subject,
      'customer_brand': @company&.email_color || '#1a1a33',
      'requester_name': @requester_name,
      'impacted_users': @impacted_users,
      'error_message': @error_message,
      'is_user_associated': @is_user_associated,
      'is_bulk': @is_bulk
      }
  end

  def create_integration_failure_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_brand': @company&.email_color || '#1a1a33',
      'integration_name': @integration_name,
      'error_code': @error_code,
      'error_message': @error_message,
      'button_url': @button_link,
      'button_cta': @email_button
    }
  end

  def create_digest_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_brand_hex': @customer_brand_hex,
      'customer_logo': @company.logo,
      'customer_name': @customer_name,
      'customer_brand_rgb': @customer_brand_rgb,
      'date_range': @date_range,
      'starting_pto_team_members': @starting_pto_team_members,
      'returning_pto_team_members': @returning_pto_team_members,
      'bday_team_members': @bday_team_members,
      'ann_team_members': @ann_team_members,
      'team_page_url': @team_page_url
    }
  end

  def create_metrics_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'statistics': @statistics,
      'customer_brand': @company&.email_color || '#1a1a33',
      'subject': @email_subject,
      'title': @email_title,
      'admin_view': @admin_view,
      'disable_url': @disable_url,
      'customer_logo': @company.logo,
      'show_time_off': @company.enabled_time_off,
      'company_name': @company.name.split.map(&:capitalize).join(' ')
    }
  end

  def create_upload_feedback_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_brand': @company&.email_color || '#1a1a33',
      'customer_logo': @company.logo,
      'title': '@email_title',
      'subject': @email_subject,
      'description': @description,
      'action_detail': @action_detail,
      'upload_detail': @upload_details,
      'receiver_name': @receiver_name,
      'sapling_login': @sapling_login,
      'successly_uploaded': @successly_uploaded,
      'uploading_error': @uploading_error,
      'defected_users': @defected_users,
      'upload_date': @upload_date
    }
  end

  def create_document_packet_assignment_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_logo': @company.logo,
      'subject': @email_subject,
      'customer_brand': @company&.email_color || '#1a1a33',
      'documents_count': @documents_count,
      'user_document_link': @user_document_link,
      'user_profile_picture': @user_profile_picture,
      'user_initials': @user_initials,
      'user_name': @user_name,
      'document_list': @document_list
    }
  end

  def create_document_flipped_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_logo': @company.logo,
      'subject': @email_subject,
      'customer_brand': @company&.email_color || '#1a1a33',
      'first_name': @first_name,
      'button_url': @button_url
    }
  end

  def send_email
    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    @response = sg.client.mail._('send').post(request_body: @body)
    @response
  end

  def from_email(company)
    SetUrlOptions.call(company, ActionMailer::Base.default_url_options)
    "#{company.subdomain}@#{ENV['DEFAULT_HOST']}"
  end

  def add_new_hires_email_data(template_obj)
    @new_hires = template_obj[:new_hires]
    @admin_view = template_obj[:admin_view]
    @disable_url = template_obj[:disable_url]
    @categories = template_obj[:categories]
  end

  def store_sendgrid_email
    tos = []
    @personalization.tos.each do |obj|
      tos.push(obj["email"])
    end
    if @digest_email
      subject = "Weekly Manager Digest 🎉"
      content = @company.digest_email_template(@template_obj)
    elsif @body.present?
      subject = @body['personalizations'][0]['dynamic_template_data'][:subject] rescue ''
      content = @template_obj[:email_type] == 'upload_feedback' ?  @content_description : @sanitized_description
    end
    content += @button_link if content && @button_link
    email = CompanyEmail.create(
      to: tos,
      bcc: @emails_bcc,
      cc: @emails_cc,
      from: @mail.from["email"],
      subject: subject,
      content: content,
      sent_at: Time.now,
      company_id: @company&.id
      ) if @body.present?

    logging.create(@company, 'Template Issue', {result: 'Template ID not present', company_email_id: email.id}, 'Email') if @template_id.nil? && email.present?

    @mail.attachments.each do |attachment|
      filename = attachment["filename"]
      if @report_filename
        file = File.new("#{Rails.root}/tmp/#{@report_filename}", "w")
        FileUtils.cp @report_file, file
      else
        file = "#{Rails.root}/public/uploads/#{filename}"
      end
      if file.present? && File.exist?(file)
        begin
          UploadedFile.create(
            entity_type: "CompanyEmail",
            entity_id: email.id,
            file: File.open(file),
            type: "UploadedFile::Attachment",
            skip_scanning: @skip_scanning
          )
        rescue
          begin
            extension = ""
            strings = filename.split('.')
            extension = strings.last if strings.count > 1
            tempfile = Tempfile.new(['attachment', "." + extension])
            tempfile.binmode
            tempfile.write attachment["content"]
            tempfile.rewind
            tempfile.close

            UploadedFile.create(
              entity_type: "CompanyEmail",
              entity_id: email.id,
              file: tempfile,
              type: "UploadedFile::Attachment",
              skip_scanning: @skip_scanning
            )
          rescue Exception => e
            logging.create(@company, 'File Attachment', {result: 'Failed to add attachments in mail', error: e.message, file_name: file, entity_type: "CompanyEmail", company_email_id: email.id}, 'Email')
          end
        end
        File.delete(file)
      else
        logging.create(@company, 'File Attachment', {result: 'Failed to add attachments in mail', file_name: file, entity_type: "CompanyEmail", company_email_id: email.id}, 'Email')
      end
    end if @mail.attachments && email
    logging.create(@company, 'SendGrid Email', {company_email_id: email.id, email_from: @mail.from["email"], request: "{x-message-id: #{@response.headers['x-message-id']}}", state: @response.status_code&.to_i}, 'Email')
  end

  def set_pto_email_variables template_obj
    @pto_type = template_obj[:pto_type]
    @pto_date = template_obj[:pto_date]
    @pto_length = template_obj[:pto_length]
    @leftover_balance = template_obj[:leftover_balance]
    @pto_comment = template_obj[:pto_comment]
    @button_cta = template_obj[:button_cta]
    @review_details_url = template_obj[:review_details_url]
    @button_secondary_cta = template_obj[:button_secondary_cta]
    @sapling_link = template_obj[:sapling_link]
    @out_of_office = template_obj[:out_of_office]
    @show_approve_deny = template_obj[:show_approve_deny]
    @nick_approved_denied = template_obj[:nick_approved_denied]
    @approved = template_obj[:approved]
    @manager_name = template_obj[:manager_name]
    @policy_name = template_obj[:policy_name]
  end

  def set_digest_email_variables template_obj
    @digest_email = true
    @customer_name = template_obj[:customer_name]
    @date_range = template_obj[:date_range]
    @customer_brand_hex = @company&.email_color || '#1a1a33'
    @customer_brand_rgb = "102,102,102"
    @starting_pto_team_members = template_obj[:starting_pto_team_members]
    @returning_pto_team_members = template_obj[:returning_pto_team_members]
    @bday_team_members = template_obj[:bday_team_members]
    @ann_team_members = template_obj[:ann_team_members]
    @team_page_url = template_obj[:team_page_url]
  end

  def set_weekly_metrices_email_variables template_obj
    @metrics_email = true
    @statistics = template_obj[:statistics]
    @customer_brand_hex = @company&.email_color || '#1a1a33'
  end

  def set_upload_feedback_email_variables template_obj
    @upload_feedback_email = true
    @receiver_name = template_obj[:receiver_name]
    @upload_details = template_obj[:upload_details]
    @action_detail = template_obj[:action_detail]
    @defected_users = template_obj[:defected_users]
    @successly_uploaded = template_obj[:successly_uploaded]
    @uploading_error = template_obj[:uploading_error]
    @upload_date = template_obj[:upload_date]
    @defective_users_filename = template_obj[:defective_users_filename]
    @defective_users_file = template_obj[:defective_users_file]
  end

  def set_ct_approval_denial_variables(template_obj)
    @custom_table_email = true
    @requester_name = template_obj[:requester_name]
    @user_name = template_obj[:user_name]
    @table_name = template_obj[:table_name]
    @ctus_date = template_obj[:ctus_date]
    @approvers = template_obj[:approvers]
    @denied_email = template_obj[:denied_email]
    @action = template_obj[:action]
  end

  def set_document_failure_variables(template_obj)
    @document_failure_email = true
    @requester_name = template_obj[:requester_name]
    @impacted_users = template_obj[:impacted_users]
    @error_message = template_obj[:error_message]
    @is_user_associated = template_obj[:is_user_associated]
    @is_bulk = template_obj[:is_bulk]
  end

  def set_integration_failure_variables(template_obj)
    @integrtation_failure_email = true
    @integration_name = template_obj[:integration_name]
    @error_code = template_obj[:error_code]
    @error_message = template_obj[:error_message]
  end

  def set_document_packet_assignment_variables template_obj
    @document_packet_assignment_email = true
    @documents_count = template_obj[:documents_count]
    @user_document_link = template_obj[:user_document_link]
    @user_profile_picture = template_obj[:user_profile_picture]
    @user_initials = template_obj[:user_initials]
    @user_name = template_obj[:user_name]
    @document_list = template_obj[:document_list]
  end

  def set_sandbox_invite_email template_obj
    @full_name = template_obj[:full_name]
    @first_name = template_obj[:first_name]
  end

  def create_sandbox_invite_email_body
    @body = @mail.to_json
    @body['personalizations'][0]['dynamic_template_data'] = {
      'customer_brand': @company&.email_color || '#1a1a33',
      'customer_logo': @company.logo,
      'subject': @email_subject,
      'button_link': @button_link,
      'full_name': @full_name,
      'first_name': @first_name
    }
  end

  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end

  def set_document_flipped_email(template_obj)
    @document_flipped_email = true
    @first_name = template_obj[:first_name]
    @button_url = template_obj[:button_url]
  end

end
