class UserMailer < ApplicationMailer
  require 'open-uri'
  require 'nokogiri'
  require 'sendgrid-ruby'
  require 'cgi'
  include SendGrid
  after_action :store_email

  def admin_user_email(admin_user)
    @admin_user = admin_user
    domain = Rails.env.production? ? 'default.saplingapp.io' : Company.active_companies.first.try(:domain)
    @active_admin_url = "https://#{domain}/admin/admin_users/sessions/change_password_form?token=#{admin_user.email_verification_token}"
    email_cc = [I18n.t('mailer.admin_user_email.cc')] if Rails.env.production?
    @email_type = 'admin_email'

    email_template_obj = {
      emails_to: @admin_user.email,
      email_from: "security@#{ENV['DEFAULT_HOST']}",
      emails_cc: email_cc,
      template_id: ENV['SG_TEXT_EMAIL'],
      description: I18n.t('mailer.admin_user_email.description', expiry_date: @admin_user.expiry_date.strftime("%m/%d/%Y")),
      email_subject: I18n.t('mailer.admin_user_email.subject'),
      email_button: 'Confirm Access',
      email_type: @email_type,
      button_link: @active_admin_url,
    }
    SendGridEmailService.new(email_template_obj).perform
  end

  def onboarding_tasks_email(invite_user, emp_name, email, tasks_count, activities_flag, owner_flag, task_type, workspace_id, user=nil, template=nil, test_email=false)
    email_cc = email_bcc = nil
    unless test_email
      @invite_user = invite_user
      @company = invite_user.company
      @emp_name, @email, @tasks_count = emp_name, email, tasks_count
      if @email == @invite_user.email && @invite_user.personal_email.present? && User.current_stages[@invite_user.current_stage] == User.current_stages['invited']
        if @invite_user.onboard_email == "personal"
          @email = @invite_user.personal_email
        elsif @invite_user.onboard_email == "both"
          @email = [@email, @invite_user.personal_email]
        end
      end
      @is_new_hire = User.current_stages[@invite_user.current_stage] == User.current_stages['invited'] && @invite_user.personal_email == @email
      @activities_flag = activities_flag
      @owner_flag = owner_flag
      @task_type =task_type

      if @task_type == "individual"
        @activity_owner = User.find_by_email(email)
      elsif @task_type == "workspace"
        @activity_owner = User.new(preferred_name: emp_name)
        @workspace_id = workspace_id
      end
      secondary_email_subject = @activities_flag ? I18n.t('mailer.new_tasks_email.subject_activities') : I18n.t('mailer.new_tasks_email.subject_onboarding')
      template = @company.email_templates.find_by_email_type('onboarding_activity_notification')

      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, invite_user, tasks_count, @activity_owner, nil, true)) : secondary_email_subject
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, invite_user) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, invite_user) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, invite_user, tasks_count, @activity_owner) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @invite_user = user
      @company = user.company
      @email_subject =  template.subject
      @email_desc = template.description
      @email = template.email_to
    end

    return unless @company.present? && @company.notifications_enabled

    @invite_user_first_name = @invite_user.preferred_name.present? ? @invite_user.preferred_name : @invite_user.first_name

    template_id = ENV['SG_TEXT_EMAIL']

    body = '<p style="margin-top:0;"></p>'
    if @email_desc.present?
      body += '<p>' + CGI.unescapeHTML(@email_desc).html_safe + '</p>'
    else
      if @activities_flag && @owner_flag
        body += '<p style="margin-top:0;">' + I18n.t('mailer.new_tasks_email.content_self', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count).html_safe + '</p>'
      elsif @activities_flag && !@owner_flag
        body += I18n.t('mailer.new_tasks_email.content_activities', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user_first_name, full_name: @invite_user.display_name).html_safe
      elsif @invite_user.team
        body += '<p style="margin-top: 0px;">'
        body += I18n.t('mailer.new_tasks_email.content_department', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user_first_name, full_name: @invite_user.display_name, company: @invite_user.company.name, start_date: @invite_user.start_date.strftime('%b %d, %Y'), department: @invite_user.team.name).html_safe
        body += '</p>'
      else
        body += '<p style="margin-top: 0px;">'
        body += I18n.t('mailer.new_tasks_email.content', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user_first_name, full_name: @invite_user.display_name, company: @invite_user.company.name, start_date: @invite_user.start_date.strftime('%b %d, %Y')).html_safe
        body += '</p>'
      end
    end
    body += '<p style="margin-top: 0px;">' + I18n.t('mailer.new_tasks_email.link_below') + '</p>'

    if @task_type == "individual"
      body_button_link = "https://#{@company.app_domain}/#/tasks/#{@activity_owner.try(:id).try(:to_s)}"
    elsif @task_type == "workspace"
      body_button_link = "https://#{@company.app_domain}/#/workspace/#{@workspace_id.try(:to_s)}/tasks"
    end

    if @email.present?
      email_cc = uniqueEmails(@email, email_cc)
      email_bcc = uniqueEmails(@email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      email_template_obj = {
        company: @company.id,
        emails_to: @email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @invite_user.id,
        description: body.html_safe,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.onboarding_tasks_email.header_top'),
        email_button: I18n.t('mailer.new_tasks_email.btn_text'),
        button_link: body_button_link
      }

      result = SendGridEmailService.new(email_template_obj).perform
      create_logging(@company, 'Onboarding Tasks Email', task_emails_log(email_template_obj, @email))
    end
  end

  def onboarding_tasks_email_with_activities(invite_user, emp_name, email, tasks_count, activities, activities_flag, owner_flag, task_type)
    @invite_user = invite_user
    @company = invite_user.company
    if email == @invite_user.email && @invite_user.personal_email.present? && User.current_stages[@invite_user.current_stage] == User.current_stages['invited']
      if @invite_user.onboard_email == "personal"
        email = @invite_user.personal_email
      elsif @invite_user.onboard_email == "both"
        email = [email, @invite_user.personal_email]
      end
    end
    @is_new_hire = User.current_stages[@invite_user.current_stage] == User.current_stages['invited']
    return if @company.blank? || !@company.notifications_enabled || (@is_new_hire && @company.send_notification_before_start && !email)
    if invite_user.preferred_name.present?
      @invite_user_first_name = invite_user.preferred_name
    else
      @invite_user_first_name = invite_user.first_name
    end

    @emp_name, @email, @tasks_count = emp_name, email, tasks_count
    @activities = activities
    @activities_flag = activities_flag
    @owner_flag = owner_flag

    @activities[:tasks].each do |t|
      t.name = fetch_text_from_html(ReplaceTokensService.new.replace_task_tokens(t.name, @invite_user))
    end
    secondary_email_subject = @activities_flag ? I18n.t('mailer.new_tasks_email.subject_activities') : I18n.t('mailer.new_tasks_email.subject_onboarding')
    if task_type == "individual"
      if @is_new_hire
        @activity_owner = @invite_user
      else
        @activity_owner = User.find_by_email(email)
      end
    elsif task_type == "workspace"
      @activity_owner = User.new(preferred_name: emp_name)
    end

    template = @company.email_templates.find_by_email_type('onboarding_activity_notification')
    @email_subject = get_email_subject(template, invite_user, tasks_count, secondary_email_subject)
    email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, invite_user)  : nil
    email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, invite_user) : nil
    @email_desc = !@is_new_hire && template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, invite_user, tasks_count, @activity_owner) : nil
    email_cc.map!(&:downcase).uniq! if email_cc
    email_bcc.map!(&:downcase).uniq! if email_bcc
    if email.present?
      email_cc = uniqueEmails(email, email_cc)
      email_bcc = uniqueEmails(email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)
      template_id = ENV['SG_LIST_EMAIL']
      description = get_email_description(template, invite_user, tasks_count)

      email_template_obj = {
        company: @company.id,
        emails_to: email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @invite_user.id,
        description: description,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.onboarding_tasks_email.header_top'),
        email_button: nil,
        button_link: nil,
        sapling_login: "https://#{@company.domain}"
      }

      result = SendGridEmailService.new(email_template_obj).perform
      create_logging(@company, 'Onboarding Tasks Email with Activities', task_emails_log(email_template_obj, @email))
    end
  end

  def start_date_change_email(user, test_email=false)
    @user = user
    template = @user.company.email_templates.find_by_email_type('start_date_change')
    @user_first_name = user.display_first_name
    email_cc = email_bcc = nil
    unless test_email
      @company = @user.company
      @email = template.present? && template.email_to.present? ? ReplaceTokensService.new.replace_tokens(template.email_to, user) : nil
      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, user)) : secondary_email_subject
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, user)  : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, user) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, user) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @email_subject =  ReplaceTokensService.new.replace_dummy_tokens(template.subject , user.company)
      @email_desc = ReplaceTokensService.new.replace_dummy_tokens(template.description,user.company)
      @email = @user.email || @user.personal_email
      @company = user.company
    end
    return unless @company.present? && @company.notifications_enabled

    to_email = fetch_email_from_html(@email)

    if to_email.size > 0
      to_email = to_email.uniq
      email_cc = uniqueEmails(to_email, email_cc)
      email_bcc = uniqueEmails(to_email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)
      template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
      email_template_obj = {
        company: @company.id,
        emails_to: to_email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: @email_desc,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.start_date_change_email.header_top'),
        email_button: I18n.t('mailer.start_date_change_email.body_center'),
        button_link: 'https://' + @company.app_domain + '/#/profile/' + @user.id.to_s
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end

  end

  def terminated_custom_alert(action_performer, user, employee, custom_alert)
    @employee = employee
    @employee_first_name = @employee.preferred_name.present? ? @employee.preferred_name : @employee.first_name
    @company = user.company
    return unless @company.present?
    @body = (@employee.display_name || @employee_first_name) + custom_alert&.body.to_s
    @action_performer = action_performer
    @time_conversion = TimeConversionService.new(@company)
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: (user.email || user.personal_email),
      template_id: template_id,
      user: @employee.id,
      description: I18n.t('mailer.terminated_custom_alert.body', action_performer_name: @action_performer.display_name, location: (@employee.location&.name.try(:titleize) || 'None'), termination_type: (@employee.termination_type.try(:titleize) || 'None'), eligible_for_rehire: (@employee.eligible_for_rehire.try(:titleize) || 'None'), termination_date: @time_conversion.perform(@employee.termination_date), last_day_worked: @time_conversion.perform(@employee.last_day_worked)),
      email_subject: custom_alert.subject,
      email_title: @body,
      email_button: I18n.t('mailer.terminated_custom_alert.link_below'),
      button_link: 'https://' + @company.app_domain + '/#/profile/' + @employee.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def custom_email(user_email_id, user_email = nil, tester = nil, template_email = false, is_resend_invite = false)
   unless user_email
      user_email = UserEmail.includes(user: :company).find_by(id: user_email_id)
      return unless user_email.present?
      user = user_email.user
      to_email = user_email.to.compact.present? ?  user_email.to.compact : user_email.get_to_email_list
      to_email = [user.personal_email] if is_resend_invite.present?
    else
      user_email = user_email
      user = tester
      test_email = true
      to_email = (tester.email || tester.personal_email)
    end
    @company = user&.company
    return unless @company.present? && @company.notifications_enabled

    email_from = !template_email && user_email.from.present? ? user_email.from : nil
    unless test_email
      return if user_email&.sent_at.present? && !is_resend_invite
      email_cc = user_email.present? && user_email.cc.present? ? fetch_bcc_cc(user_email.cc, user)  : nil
      email_bcc = user_email.present? && user_email.bcc.present? ? fetch_bcc_cc(user_email.bcc, user) : nil
    end
    if template_email
      email_subject =  fetch_text_from_html(ReplaceTokensService.new.replace_dummy_tokens(user_email.subject , @company))
      email_desc = ReplaceTokensService.new.replace_dummy_tokens(user_email.description, @company)
    else
      email_subject =  fetch_text_from_html(ReplaceTokensService.new.replace_tokens(user_email.subject, user_email.user))
      email_desc = user_email.present? && user_email.description.present? ? ReplaceTokensService.new.replace_tokens(user_email.description, user_email.user) : nil
    end

    email_cc.map!(&:downcase).uniq! if email_cc
    email_bcc.map!(&:downcase).uniq! if email_bcc
    to_email = to_email.uniq if to_email && to_email.class == Array
    email_cc = uniqueEmails(to_email, email_cc)
    email_bcc = uniqueEmails(to_email, email_bcc)
    email_bcc = uniqueEmails(email_cc, email_bcc)

    if user_email.schedule_options.present? && user_email.schedule_options['set_onboard_cta'].present?
      user.create_history_and_send_slack_message_on_invite unless test_email
      invite = test_email ? user_email.try(:invite) : user.invites.take
      if !test_email && !invite
        invite = user.invites.create
      end
      email_button = 'Start Onboarding'
      button_link = "https://#{@company.app_domain}/#/invite/#{invite.try(:token)}"
    else
      email_title = email_button = button_link = nil
    end
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: user.company_id,
      emails_to: to_email,
      email_from: email_from,
      emails_cc: email_cc.present? ? email_cc : nil,
      emails_bcc: email_bcc.present? ? email_bcc : nil,
      template_id: template_id,
      user: user.id,
      description: email_desc,
      email_subject: email_subject,
      email_title: email_title,
      email_attachments: user_email.attachments,
      email_button: email_button,
      button_link: button_link,
      skip_scanning: true
    }
    result = SendGridEmailService.new(email_template_obj).perform
    unless test_email
      user_email.email_status = UserEmail.statuses[:completed]
      user_email.sent_at = user_email.set_send_at
      user_email.to = to_email
      val = result.headers['x-message-id'][0] rescue nil
      user_email.message_id = val
      user_email.activity["status"] = 'Processed' if val.present?
      user_email.save
    end
  end

  def new_tasks_email(invite_user, emp_name, email, tasks_count, activities_flag, owner_flag, task_type, workspace_id, user=nil, template=nil, test_email=false, bulk_task_reassign_mail=false)
    email_cc = email_bcc = nil
    if bulk_task_reassign_mail
      return if !invite_user || tasks_count == 0
      @user = invite_user
      @tasks_count = tasks_count
      @company = @user.company
      @user_first_name = @user.display_first_name
      @task_type = "individual"
      @activity_owner = invite_user

      @email = @user.email || @user.personal_email
      @email_subject = "#{@tasks_count} task(s) are assigned to you"
      @email_desc = "Hey #{@user_first_name}, #{@tasks_count} tasks are assigned to you.<br>Click on button below to see your tasks."

    elsif !test_email
      @invite_user = invite_user
      @emp_name, @email, @tasks_count = emp_name, email, tasks_count
      @company = invite_user.company
      @activities_flag = activities_flag
      @owner_flag = owner_flag
      @task_type = task_type

      if @task_type == "individual"
        @activity_owner = User.find_by_email(email)
      elsif @task_type == "workspace"
        @activity_owner = User.new(preferred_name: emp_name)
        @workspace_id = workspace_id
      end

      secondary_email_subject = @activities_flag ? I18n.t('mailer.new_tasks_email.subject_activities') : I18n.t('mailer.new_tasks_email.subject_onboarding')
      template = @company.email_templates.find_by_email_type('transition_activity_notification')

      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, invite_user, tasks_count, @activity_owner, nil, true)) : secondary_email_subject
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, invite_user) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, invite_user) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, invite_user, tasks_count, @activity_owner) : nil
    else
      @email_subject =  fetch_text_from_html(template.subject)
      @email_desc = template.description
      @invite_user = user
      @email = template.email_to
      @company = user.company
    end
    return unless @company.present? && (@company.notifications_enabled || bulk_task_reassign_mail)
    if @email.present?
      email_cc = uniqueEmails(@email, email_cc)
      email_bcc = uniqueEmails(@email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      body = ""
      if @email_desc.present?
        body += '<p>' +CGI.unescapeHTML(@email_desc).html_safe + '</p>'
      else
        if @activities_flag && @owner_flag
          body += '<p style="margin-top:0;">' + I18n.t('mailer.new_tasks_email.content_self', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count).html_safe + '</p>'
        elsif @activities_flag && !@owner_flag
          body += I18n.t('mailer.new_tasks_email.content_activities', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user.first_name, full_name: @invite_user.full_name).html_safe
        elsif @invite_user.team
          body += '<p style="margin-top: 0px;">' + I18n.t('mailer.new_tasks_email.content_department', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user.first_name, full_name: @invite_user.full_name, company: @invite_user.company.name, start_date: @invite_user.start_date.strftime('%b %d, %Y'), department: @invite_user.team.name).html_safe
          body += '</p>'
        else
          body += '<p style="margin-top: 0px;">' + I18n.t('mailer.new_tasks_email.content', tasks_in_words: @tasks_count.humanize.capitalize, tasks_num: @tasks_count, first_name: @invite_user.first_name, full_name: @invite_user.full_name, company: @invite_user.company.name, start_date: @invite_user.start_date.strftime('%b %d, %Y')).html_safe
          body += '</p>'
        end
        body += '<p style="margin-top: 0px;"></p>'
        body += I18n.t('mailer.new_tasks_email.link_below')
      end

      if @task_type == "individual"
        body_button_link = "https://#{@company.app_domain}/#/tasks/#{@activity_owner.try(:id).try(:to_s)}"
      elsif @task_type == "workspace"
        body_button_link = "https://#{@company.app_domain}/#/workspace/#{@workspace_id.try(:to_s)}/tasks"
      end

      if !@user
        @user = @invite_user
      end

      template_id = ENV['SG_TEXT_EMAIL']
      email_template_obj = {
        company: @company.id,
        emails_to: @email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: body,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.new_tasks_email.header_top'),
        email_button: I18n.t('mailer.new_tasks_email.btn_text'),
        button_link: body_button_link
      }
      result = SendGridEmailService.new(email_template_obj).perform
      create_logging(@company, 'New Tasks Email', task_emails_log(email_template_obj, @email))
    end
  end

  def new_tasks_email_with_activities(invite_user, emp_name, email, tasks_count, activities, activities_flag, owner_flag, task_type, user=nil, email_template=nil, test_email=false)
    email_cc = email_bcc = nil
    unless test_email
      @invite_user = invite_user
      @emp_name, @email, @tasks_count = emp_name, email, tasks_count
      @company = invite_user.company
      @activities = activities
      @activities_flag = activities_flag
      @owner_flag = owner_flag
      if invite_user.preferred_name.present?
        @first_name = invite_user.preferred_name
      else
        @first_name = invite_user.first_name
      end
      if @activities[:tasks] && @activities[:tasks].count > 0
        @activities[:tasks].each do |t|
          t.name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(t.name, @invite_user))
        end
      end
      template = @company.email_templates.find_by_email_type('transition_activity_notification')
      secondary_email_subject = @activities_flag ? I18n.t('mailer.new_tasks_email.subject_activities') : I18n.t('mailer.new_tasks_email.subject_onboarding')
      if task_type == "individual"
        @activity_owner = User.find_by_email(email)
      elsif task_type == "workspace"
        @activity_owner = User.new(preferred_name: emp_name)
      end
      template = @company.email_templates.find_by_email_type('transition_activity_notification')
      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, invite_user, tasks_count, @activity_owner, nil, true)) : secondary_email_subject
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, invite_user)  : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, invite_user) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, invite_user, tasks_count, @activity_owner) : nil
    else
      @email = template.email_to
      @company = user.company
      @invite_user = user
      template = email_templates
      @email_subject =  fetch_text_from_html(template.subject)
      @email_desc = template.description
    end
    return unless @company.present? && @company.notifications_enabled
    if @email.present?
      body = get_new_tasks_list
      template_id = ENV['SG_LIST_EMAIL']
      email_template_obj = {
        company: @company.id,
        emails_to: @email,
        emails_cc: nil,
        emails_bcc: nil,
        email_attachments: nil,
        template_id: template_id,
        user: @invite_user.id,
        description: body,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.new_tasks_email.header_top'),
        email_button: nil,
        button_link: nil,
        sapling_login: "https://#{@company.domain}"
      }
      result = SendGridEmailService.new(email_template_obj).perform
      create_logging(@company, 'Onboarding Tasks Email with Activities', task_emails_log(email_template_obj, @email))
    end
  end

  def task_reassign_email(task_user_connection)
    @user = task_user_connection.owner
    @company = @user.company
    return unless @company.present? && @company.notifications_enabled
    @old_user = task_user_connection.user
    @user_first_name = @user.display_first_name
    @old_user_first_name = @old_user.display_first_name
    @due_date = task_user_connection.due_date
    @task_name = fetch_text_from_html ReplaceTokensService.new.replace_tokens(task_user_connection.task.try(:name), task_user_connection.user, nil , nil, nil, true)
    @email = @user.email || @user.personal_email

    emails = uniqueEmails(@email, emails)

    body = 'Hi ' + @user_first_name + '! <br/><br/>You have been assigned a task to complete for ' + @old_user_first_name + ' ' + @old_user.last_name
    body += ' by ' + @due_date.to_s + '.<br/><br/><b>' + @task_name +'</b><br/><br/>Use the link below to see all of your tasks.'

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: @email,
      template_id: template_id,
      user: @old_user.id,
      description: body,
      email_subject: 'New task assigned for ' + @old_user_first_name + ' ' + @old_user.last_name,
      email_title: 'Task re-assigned for ' + @old_user_first_name,
      email_button: 'Go to my tasks',
      button_link: 'https://' + @company.app_domain + '/#/tasks/' + @user.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def overdue_task_email(user_id, company_id, workspace = nil)
    timeout_try = 0
    eof_try = 0
    begin
      @company = Company.find_by(id: company_id)
      return unless @company.present? && @company.notifications_enabled
      if workspace != nil
        @user = User.new(preferred_name: workspace.name)
        email = workspace.get_distribution_emails
        @link = 'https://' + @company.app_domain + '/#/workspace/' + workspace.id.to_s + '/tasks'
      else
        @user = @company.users.find_by(id: user_id)
        return unless @user.present?
        email = @user.email || @user.personal_email
        @link = 'https://' + @company.app_domain + '/#/tasks/' + @user.id.to_s
      end

      if @user.preferred_name.present?
        @user_name = @user.preferred_name
      else
        @user_name = @user.first_name
      end
      return if email.blank?

      template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

      email_template_obj = {
        company: @company.id,
        emails_to: email,
        emails_cc: nil,
        emails_bcc: nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: I18n.t('mailer.overdue_task_email.hey', name: (@user_name)) + '<br/><br/>' + I18n.t('mailer.overdue_task_email.body').html_safe,
        email_subject: I18n.t('mailer.overdue_task_email.subject'),
        email_title: I18n.t('mailer.overdue_task_email.header_top'),
        email_button: I18n.t('mailer.overdue_task_email.link_below'),
        button_link: @link
      }

      result = SendGridEmailService.new(email_template_obj).perform
      create_logging(@company, 'Send Overdue Task Email', over_due_task_log(email_template_obj, email, workspace))
    rescue Net::ReadTimeout => e
      timeout_try += 1
      raise if timeout_try == 5
      retry
    rescue EOFError => e
      eof_try += 1
      raise if eof_try == 5
      retry
    end
  end

  def overdue_document_email(user_id)
    @user = User.find_by(id: user_id)
    @company = Company.find_by(id: @user.company_id) rescue nil
    return unless @company.present? && @company.notifications_enabled

    email = @user.email || @user.personal_email

    logger.info '+' * 100
    logger.info from_email(@company)
    logger.info '+' * 100

    if @user.preferred_name.present?
      @user_name = @user.preferred_name
    else
      @user_name = @user.first_name
    end
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: I18n.t('mailer.overdue_document_email.hey', name: (@user_name)) + '<br/><br/>' + I18n.t('mailer.overdue_document_email.body').html_safe,
      email_subject: I18n.t('mailer.overdue_document_email.subject'),
      email_title: I18n.t('mailer.overdue_document_email.header_top'),
      email_button: I18n.t('mailer.overdue_document_email.link_below'),
      button_link: 'https://' + @company.app_domain + '/#/documents/' + @user.id.to_s
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def bulk_onboarding_email_for_sarah_or_peter(user_id, email_data, email_for_sarah = true)
    user = User.find_by(id: user_id)
    @company = user.company rescue nil
    return unless @company.present? && @company.notifications_enabled
    email = user.email || user.personal_email

    if email_for_sarah
      template_id = ENV['SG_BULK_ONBOARDING_SARAH_EMAIL']
      email_subject = '[Sapling] Your Bulk Onboarding request is complete'
    else
      template_id = ENV['SG_BULK_ONBOARDING_PETER_EMAIL']
      email_subject = '[Sapling] Meet your new team members!'
    end

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: email_subject,
      template_id: template_id,
      user: user.id,
      bulk_email_data: email_data
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_team_digest_email(user, data, super_user)
    data[:company] = user.company_id
    if super_user.present?
      data[:emails_to] = super_user.email || super_user.personal_email
    else
      data[:emails_to] = user.email || user.personal_email
    end
    data[:template_id] = ENV['SG_DIGEST_EMAIL']
    data[:digest_email] = true
    data[:customer_name] = user.display_name
    data[:team_page_url] = "https://#{user.company.app_domain}/#/team/#{user.id}"
    result = SendGridEmailService.new(data).perform
  end

  def is_document_overdue(user)
    past_due_date = user.start_date + 2.months + 1.day
    today = Date.today
    today > past_due_date
  end

  def buddy_manager_change_email(employee, buddy_manager, buddy_manager_email, template_type, template=nil, test_email=false, buddy_manager_name)
    employee = User.find_by(id: employee) if employee.present? && employee.is_a?(Integer)
    buddy_manager = User.find_by(id: buddy_manager) if buddy_manager.present? && buddy_manager.is_a?(Integer)
    return unless employee.present?

    unless buddy_manager_name == 'Manager'
      employee.buddy = buddy_manager
    end
    @user = employee
    @company = employee.company
    return unless @company.present? && @company.notifications_enabled
    if employee.preferred_name.present?
      @first_name = employee.preferred_name
    else
      @first_name = employee.first_name
    end
    email_cc = email_bcc = nil
    unless test_email
      @email = buddy_manager_email
      template = @company.email_templates.find_by_email_type(template_type)
      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, employee, nil, nil, nil, true)) : nil
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, employee)  : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, employee) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, employee) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @email = template.email_to
      @email_subject =  fetch_text_from_html(template.subject)
      @email_desc = template.description
    end
    email_cc = uniqueEmails(@email, email_cc)
    email_bcc = uniqueEmails(@email, email_bcc)
    email_bcc = uniqueEmails(email_cc, email_bcc)

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: @email,
      emails_cc: email_cc.present? ? email_cc : nil,
      emails_bcc: email_bcc.present? ? email_bcc : nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: @email_desc,
      email_subject: fetch_text_from_html(@email_subject),
      email_title: I18n.t('mailer.buddy_manager_change_email.header_top'),
      email_button: I18n.t('mailer.buddy_manager_change_email.link_below', first_name: @first_name),
      button_link: 'https://' + @company.app_domain + '/#/profile/' + @user.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def change_password_email(user)
    @user = user
    email = user.last_logged_in_email || user.email || user.personal_email
    @company = user.company
    @redirect_url = 'mailto:help@trysapling.com'
    if user.preferred_name.present?
      @first_name = user.preferred_name
    else
      @first_name = user.first_name
    end
    return unless @company.present?

    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    description = '<p>' + I18n.t('mailer.change_password_email.hello', name: @first_name) + '</p><br><br><p>' + I18n.t('mailer.change_password_email.message').html_safe + '</p>'

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: description,
      email_subject: I18n.t('mailer.change_password_email.subject'),
      email_title: I18n.t('mailer.change_password_email.header_top'),
      email_button: I18n.t('mailer.change_password_email.contact_us'),
      button_link: @redirect_url
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def ghost_user_password(user, creator)
    @user = user
    email = user.last_logged_in_email || user.email || user.personal_email
    @company = user.company
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.reset_password_token = hashed_token
    user.reset_password_sent_at = Time.now.utc
    user.save!
    callback_url = CGI.escape("https://#{@company.app_domain}/#/reset_password")
    @redirect_url = "https://#{@company.domain}/api/v1/auth/password/edit?config=default&redirect_url=#{callback_url}&reset_password_token=#{raw_token}"
    if user.preferred_name.present?
      @first_name = user.preferred_name
    else
      @first_name = user.first_name
    end

    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    description = '<p>Hi there!<br/><br/>' + "You’ve been given Temporary Administrator access until #{user.expires_in.strftime('%d/%m/%Y')}.<br/><br/> Before continuing, please use the link below to setup your password." + '</p><br/>' + "Your access will auto-expire on #{user.expires_in.strftime('%d/%m/%Y')}<br/><br/>Thanks!<br/>"

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: creator.email,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: description,
      email_subject: 'New Admin Created in Sapling',
      email_title: 'Please authorize your account to continue',
      email_button: 'Confirm Access',
      button_link: @redirect_url
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def offboarding_tasks_email(employee, invited, count, task_type=nil, template=nil, test_email=false)
    @company = employee.company
    return unless @company.present? && @company.notifications_enabled
    email_cc = email_bcc = nil
    @employee = employee
    @task_type = task_type
    if employee.preferred_name.present?
      @employee_first_name = employee.preferred_name
    else
      @employee_first_name = employee.first_name
    end
    unless test_email
      @tasks_count = count
      if task_type == "workspace"
        activity_owner = invited
        @email = @company.workspaces.find_by(id: activity_owner.id).try(:get_distribution_emails)
      else
        activity_owner = @company.users.find_by(id: invited)
        @email = activity_owner.email || activity_owner.personal_email
      end

      @invited = activity_owner

      template = @company.email_templates.find_by_email_type('offboarding_activity_notification')
      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, employee, count, activity_owner, nil, true)) : I18n.t('mailer.offboarding_tasks_email.header_top')
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, employee) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, employee) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, employee, count, activity_owner) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @invited = employee
      @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(template.subject) : I18n.t('mailer.offboarding_tasks_email.header_top')
      @email_desc = template.description
      @email = template.email_to
    end
    if @email.present?
      email_cc = uniqueEmails(@email, email_cc)
      email_bcc = uniqueEmails(@email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      template_id = ENV['SG_TEXT_EMAIL']
      if @task_type == "workspace"
        button_link = "https://#{@company.app_domain}/#/workspace/#{@invited.try(:id).try(:to_s)}/tasks"
      else
        button_link = "https://#{@company.app_domain}/#/tasks/#{@invited.try(:id).try(:to_s)}"
      end
      email_template_obj = {
        company: @company.id,
        emails_to: @email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @employee.id,
        description: @email_desc,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.offboarding_tasks_email.header_top'),
        email_button: I18n.t('mailer.offboarding_tasks_email.offboarding'),
        button_link: button_link
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def offboarding_tasks_email_with_activities(employee, invited, count, activities, task_type=nil)
    @employee = employee
    @company = employee.company
    return unless @company.present? && @company.notifications_enabled
    @task_type = task_type
    if employee.preferred_name.present?
      @employee_first_name = employee.preferred_name
    else
      @employee_first_name = employee.first_name
    end
    @tasks_count = count
    @activities = activities

    @activities[:tasks].each do |t|
      t.name = fetch_text_from_html(ReplaceTokensService.new.replace_task_tokens(t.name, @employee))
    end

    template = @company.email_templates.find_by_email_type('offboarding_activity_notification')
    if @task_type == "workspace"
      activity_owner = invited
      email = @company.workspaces.find_by(id: activity_owner.id).try(:get_distribution_emails)
    else
      activity_owner = @company.users.find_by(id: invited)
      email = activity_owner.email || activity_owner.personal_email
    end

    @invited = activity_owner

    @email_subject =  template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_task_tokens(template.subject, employee, count, activity_owner, nil,true)) : I18n.t('mailer.offboarding_tasks_email.header_top')
    email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, employee) : nil
    email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, employee) : nil
    @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_task_tokens(template.description, employee, count, activity_owner) : nil
    email_cc.map!(&:downcase).uniq! if email_cc
    email_bcc.map!(&:downcase).uniq! if email_bcc

    if email.present?
      description = get_task_list
      email_cc = uniqueEmails(email, email_cc)
      email_bcc = uniqueEmails(email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      template_id = ENV['SG_LIST_EMAIL']
      email_template_obj = {
        company: @company.id,
        emails_to: email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @employee.id,
        description: description,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.offboarding_tasks_email.header_top'),
        email_button: nil,
        button_link: nil,
        sapling_login: "https://#{@company.domain}"
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def send_request_information_notification_to_requested_to(request_information)
    @requester = request_information.requester
    @requested_to = request_information.requested_to
    @company = request_information.company
    @request_information_id = request_information.id
    @token = @requested_to.ensure_request_information_form_token.to_s

    return unless @company.present?

    if @requester.preferred_name.present?
      @requester_first_name = @requester.preferred_name
    else
      @requester_first_name = @requester.first_name
    end
    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: (@requested_to.email || @requested_to.personal_email),
      template_id: template_id,
      user: @requester.id,
      description: I18n.t('mailer.send_request_information_notification_to_requested_to.body', name: (@requested_to.preferred_name || @requested_to.first_name), requester_name: @requester.display_name),
      email_subject: I18n.t('mailer.send_request_information_notification_to_requested_to.subject'),
      email_title: I18n.t('mailer.send_request_information_notification_to_requested_to.subject'),
      email_button: I18n.t('mailer.notify_account_creator_about_manager_form_completion_email.link_below'),
      button_link: 'https://' + @company.app_domain + '/#/requested_information/' + @request_information_id.to_s + '/' + @token
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_request_information_notification_to_requester(request_information)
    @requester = request_information.requester
    @requested_to = request_information.requested_to
    @company = request_information.company

    return unless @company.present?

    profile_field_ids = request_information.profile_field_ids
    @profile_fields = @company.custom_fields.where(id: profile_field_ids).pluck(:name)

    @profile_fields.push('First Name') if profile_field_ids.include?('fn')
    @profile_fields.push('Last Name') if profile_field_ids.include?('ln')
    @profile_fields.push('Personal Email') if profile_field_ids.include?('pe')
    @profile_fields.push('Preferred Name') if profile_field_ids.include?('pn')
    @profile_fields.push('About') if profile_field_ids.include?('abt')

    description = I18n.t('mailer.send_request_information_notification_to_requester.body1', requested_to_name: @requested_to.display_name, requester_name: (@requester.preferred_name || @requester.first_name))
    @profile_fields.each do |profile_field|
      description += "<li><b>#{profile_field}</b></li>"
    end
    description += I18n.t('mailer.send_request_information_notification_to_requester.body2', requested_to_name: (@requested_to.preferred_name || @requested_to.first_name), requester_name: (@requester.preferred_name || @requester.first_name))

    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: (@requester.email || @requester.personal_email),
      template_id: template_id,
      user: @requested_to.id,
      description: description,
      email_subject: I18n.t('mailer.send_request_information_notification_to_requester.subject'),
      email_title: I18n.t('mailer.send_request_information_notification_to_requester.subject'),
      email_button: I18n.t('mailer.send_request_information_notification_to_requester.link_below'),
      button_link: 'https://' + @company.app_domain + '/#/profile/' + @requested_to.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def invite_user(user, user_details=nil, google_auth_enable=false, template=nil, test_email=false)
    @user = user
    @email_type = 'invite_user'
    @company = @user.company
    return unless @company.present?
    email = @user.get_invite_email_address
    @google_auth_enable = google_auth_enable
    @template = template
    if user.preferred_name.present?
      @first_name = user.preferred_name
    else
      @first_name = user.first_name
    end

    unless test_email
      if @google_auth_enable
        @redirect_url = user_details
      else
        raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
        @user.reset_password_token = hashed_token
        @user.reset_password_sent_at = Time.now.utc
        if User.current.present?
          data = { user: @user.inspect, current_user: User.current.id }
          create_logging(@company, 'User Belongs To Another Company', { result: data })
        end
        user.save!
        callback_url = CGI.escape("https://#{@company.app_domain}/#/reset_password")
        @redirect_url = "https://#{@company.domain}/api/v1/auth/password/edit?config=default&redirect_url=#{callback_url}&reset_password_token=#{raw_token}&cid=#{@company.id}"
      end

      unless @template
        @template = @company.email_templates.find_by_email_type("invite_user")
      end
      @email_subject =  ReplaceTokensService.new.replace_tokens(@template.subject, user)
      @email_desc = ReplaceTokensService.new.replace_tokens(@template.description, user)
    else
      @redirect_url = "https://#{@company.domain}/"
      @email_subject =  ReplaceTokensService.new.replace_dummy_tokens(@template.subject , user.company)
      @email_desc = ReplaceTokensService.new.replace_dummy_tokens(@template.description, user.company)
    end
    email_cc = @template.present? && @template.cc.present? ? fetch_bcc_cc(@template.cc, user) : nil
    email_bcc = @template.present? && @template.bcc.present? ? fetch_bcc_cc(@template.bcc, user) : nil
    @company = user.company
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: email_cc,
      emails_bcc: email_bcc,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: @email_desc,
      email_subject: Nokogiri::HTML(@email_subject).xpath("//text()").to_s,
      email_title: I18n.t('mailer.invite_user.header_top'),
      email_button: I18n.t('mailer.invite_user.get_started'),
      email_type: @email_type,
      button_link: @redirect_url
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def notify_comment_mentioned_user(mentioned_user, comment)
    @company = mentioned_user.company
    @comment = comment

    return if !(@company.present? && @company.notifications_enabled)
    @user = mentioned_user
    @user_first_name = @user.display_first_name
    @commenter_first_name = comment.commenter.display_first_name
    email = ((@user.start_date > Date.today || !@user.email.present?) && @user.personal_email.present?) ? @user.personal_email : @user.email

    if @comment.commentable_type == "TaskUserConnection"
      message_type = "Task"
      task_user_connection = TaskUserConnection.find_by(id: @comment.commentable_id)
      email_button_text = "Respond to this Task in Sapling"
      is_authorize = (@user.user_role.role_type != 'employee' &&
                      @user.user_role.permissions['platform_visibility']['task'] == 'view_and_edit')
      button_url =
        if @user.id == task_user_connection&.user_id || is_authorize
          "https://#{@company.app_domain}/#/tasks/#{task_user_connection&.user_id}?id=#{task_user_connection&.id}"
        else
          "https://#{@company.app_domain}/#/tasks/#{mentioned_user&.id}"
        end
    elsif @comment.commentable_type == "PtoRequest"
      message_type = "PTO Request"
      pto_request = PtoRequest.find_by(id: @comment.commentable_id)
      email_button_text = "Respond to this Time Off Request in Sapling"
      button_url = 'https://' + @company.app_domain + '/#/time_off/' + pto_request.user&.id.to_s + '?id=' + pto_request.id.to_s
    end

    if @comment.commenter.picture.present?
      img_src = @comment.commenter.picture
    else
      img_src = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTkF8Lw_tDKvUUjFCbFmAcDQFqAS2IHXX8ncf1HsqdIzMGW7QjT8g"
    end

    template_id = ENV['SG_COMMENT_EMAIL']

    @description = @comment.description
    @comment.mentioned_users.each do |m|
      string_to_replace = "USERTOKEN[" + m.to_s + "]"
      user = @company.users.find_by_id(m)
      @description = @description.gsub string_to_replace, "@" + user.display_name
    end

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: nil,
      message_type: message_type,
      message_sender: @commenter_first_name,
      message: @description,
      user_avatar_url: img_src,
      email_subject: I18n.t('mailer.notify_comment_mentioned_user.subject'),
      email_title: nil,
      email_button: email_button_text,
      button_link: button_url
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def notify_comment_task_owner(comment)
    @comment = comment
    @company = @comment.company
    return if !@company.present? || !@company.notifications_enabled || !@comment.commentable.present?

    task_type_check = false
    @user = @company.users.find_by_id(@comment.commentable.owner.id)
    agent_id = comment.commentable.activities.where("description like ?", "%assigned the task%")[0]&.agent_id || @user.id
    @task_creater = @company.users.find_by_id(agent_id)

    tuc = @user.task_owner_connections.with_deleted.find_by(id: @comment.commentable_id)
    task = tuc.try(:task)
    if task && task.owner_id? && task.task_type != 'hire'
      task_type_check = true
    end

    if task_type_check
      return if !task.present? || task.owner_id == @comment.commenter_id || (task.owner_id.nil? && tuc.owner_id == @comment.commenter_id)
    else
      return if @comment.mentioned_users?
    end

    @comment.mentioned_users.each do |m|
      return if(m.to_s === @comment.commentable.owner.id.to_s)
    end

    if @user.preferred_name.present?
      @user_first_name = @user.preferred_name
    else
      @user_first_name = @user.first_name
    end
    if comment.commenter.preferred_name.present?
      @commenter_first_name = comment.commenter.preferred_name
    else
      @commenter_first_name = comment.commenter.first_name
    end
    if task_type_check
      email = ((@user.start_date > Date.today || !@user.email.present?) && @user.personal_email.present?) ? @user.personal_email : @user.email
    else
      email = ((@task_creater.start_date > Date.today || !@task_creater.email.present?) && @task_creater.personal_email.present?) ? @task_creater.personal_email : @task_creater.email
    end
    @task_name = fetch_text_from_html(ReplaceTokensService.new.replace_tokens(task&.name, @user))

    if @comment.commentable_type == "TaskUserConnection"
      message_type = "Task"
    else
      message_type = "PTO Request"
    end

    if @comment.commenter.picture.present?
      img_src = @comment.commenter.picture
    else
      img_src = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcTkF8Lw_tDKvUUjFCbFmAcDQFqAS2IHXX8ncf1HsqdIzMGW7QjT8g"
    end

    template_id = ENV['SG_COMMENT_EMAIL']

    @description = @comment.description

    @comment.mentioned_users.each do |m|
      string_to_replace = "USERTOKEN[" + m.to_s + "]"
      user = @company.users.find_by_id(m)
      @description = @description.gsub string_to_replace, "@" + user.display_name
    end

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: nil,
      task_name: @task_name,
      message_type: message_type,
      message_sender: @commenter_first_name,
      message: @description,
      user_avatar_url: img_src,
      email_subject: I18n.t('mailer.notify_comment_task_owner.subject'),
      email_title: I18n.t('mailer.notify_comment_task_owner.title'),
      email_button: "Respond to this task in Sapling",
      button_link: 'https://' + @company.app_domain + '/#/tasks/' + @comment.commentable.owner.id.to_s + '?id=' + @comment.commentable.id.to_s
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def preboarding_complete_email(user, template, zip_file_url = nil, zip_filename = nil, test_email = false)
    @user = user
    @company = @user.company
    return unless @company.present? && @company.notifications_enabled
    @user_first_name = user.display_first_name
    @team_name = @user.team.name if @user.team && @user.team.name
    email_cc = email_bcc = nil
    unless test_email
      @template = @company.email_templates.find_by_email_type("preboarding")

      @email_subject =  @template.present? && @template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(@template.subject, user, nil, nil, nil, true)) : I18n.t('mailer.preboarding_complete_email.subject', first_name: @user_first_name, last_name: @user.last_name)
      @email = @template.present? && @template.email_to.present? ? ReplaceTokensService.new.replace_tokens(@template.email_to, user) : user.account_creator.email
      email_cc = @template.present? && @template.cc.present? ? fetch_bcc_cc(template.cc, user) : nil
      email_bcc = @template.present? && @template.bcc.present? ? fetch_bcc_cc(template.bcc, user) : nil
      @email_desc = @template.present? && @template.description.present? ? ReplaceTokensService.new.replace_tokens(@template.description, user) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @template = template

      @email_subject =  @template.subject.present? ? fetch_text_from_html(@template.subject) : I18n.t('mailer.preboarding_complete_email.subject', first_name: @user_first_name, last_name: @user.last_name)
      @email = @template.email_to
      @email_desc = @template.description
    end

    if user.original_picture
      file = begin
        if Rails.env.development? || Rails.env.test?
          file_path = "#{Rails.root}/public#{user.original_picture}"
          File.read(file_path)

        else
          open(user.original_picture).read
        end
      end
      attachment_name = user.preferred_full_name + File.extname(URI.parse(user.original_picture).path)
      attachments[attachment_name] = file
    end

    to_email = fetch_email_from_html(@email)
    template_id = ENV['SG_TEXT_EMAIL']
    if to_email.size > 0
      to_email = to_email.uniq
      email_cc = uniqueEmails(to_email, email_cc)
      email_bcc = uniqueEmails(to_email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      email_template_obj = {
        company: @company.id,
        emails_to: to_email.uniq,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: @email_desc,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.preboarding_complete_email.header_top'),
        email_button: I18n.t('mailer.notify_account_creator_about_manager_form_completion_email.link_below'),
        button_link: 'https://' + @company.app_domain + '/#/profile/' + @user.id.to_s,
        completed_documents_zip_file: zip_file_url,
        completed_documents_zip_filename: zip_filename
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def notify_manager_to_provide_information_email(employee, manager, template=nil, test_email=false)
    @test_email = test_email
    @user = employee
    @company = employee.company

    return unless @company.present? && @company.notifications_enabled
    @user_first_name = employee.display_first_name
    email_cc = email_bcc = nil
    unless test_email
      @manager = manager
      @token = manager.ensure_manager_form_token.to_s
      template = @company.email_templates.find_by_email_type('new_manager_form')
      @email_subject = template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, employee, nil, nil, nil, true)) : I18n.t('mailer.notify_manager_to_provide_information_email.subject')
      @email = template.present? && template.email_to.present? ? ReplaceTokensService.new.replace_tokens(template.email_to, employee) : manager.email || manager.personal_email
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, employee) : nil
      @email_desc = template.present? && template.description.present? ?  ReplaceTokensService.new.replace_tokens(template.description, employee) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, employee) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @email_subject = template.subject.present? ? fetch_text_from_html(template.subject) : I18n.t('mailer.notify_manager_to_provide_information_email.subject')
      email_cc = template.cc
      email_bcc = template.bcc
      @email = template.email_to
      @email_desc = template.description
    end

    to_email = fetch_email_from_html(@email)
    template_id = ENV['SG_TEXT_EMAIL']

    if @test_email
      body_button_link = 'https://' + @company.app_domain + '/#/team/' + @user.manager_id.to_s + '?id=' + @user.id.to_s
    end
    if !@test_email
      body_button_link = 'http://' + @company.app_domain + '/#/manager_form/' + @user.id.to_s + '/' + @token
    end

    if to_email.size > 0
      to_email = to_email.uniq
      email_cc = uniqueEmails(to_email, email_cc)
      email_bcc = uniqueEmails(to_email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      email_template_obj = {
        company: @company.id,
        emails_to: to_email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: @email_desc,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.notify_manager_to_provide_information_email.subject'),
        email_button: I18n.t('mailer.notify_manager_to_provide_information_email.link_below'),
        button_link: body_button_link
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def send_document_completion_email(user, document, company, test_email=false, doc_template=nil)
    email_cc = email_bcc = nil
    @user = user
    @user_first_name = user.display_first_name
    @company = company
    return unless @company.present? && @company.notifications_enabled
    unless test_email
      return unless @company.document_completion_emails

      template = company.email_templates.find_by_email_type('document_completion')
      @email_subject = template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, user, nil, nil, document, true)) : ''
      @email = template.present? && template.email_to.present? ? ReplaceTokensService.new.replace_tokens(template.email_to, user, nil, nil, document) : nil
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, user) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, user, nil, nil, document) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, user) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @email_subject = fetch_text_from_html(doc_template.subject)
      @email = doc_template.email_to
      @email_desc = doc_template.description
    end

    to_email = fetch_email_from_html(@email)
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

    if to_email.size > 0
      to_email = to_email.uniq
      email_cc = uniqueEmails(to_email, email_cc)
      email_bcc = uniqueEmails(to_email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      email_template_obj = {
        company: @company.id,
        emails_to: to_email,
        emails_cc: email_cc,
        emails_bcc: email_bcc,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: @email_desc.present? ? CGI.unescapeHTML(@email_desc).html_safe : nil,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.document_completion.header_top'),
        email_button: I18n.t('mailer.document_completion.link_below', first_name: @user_first_name),
        button_link: 'https://' + @company.app_domain + '/#/documents/' + @user.id.to_s
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def notify_account_creator_about_manager_form_completion_email(employee_id, account_creator, manager, template, test_email=false)
    @user = employee = User.find(employee_id)
    email_cc = email_bcc = nil
    @manager = manager.present? ? manager : User.where(super_user: true).first
    if @manager.preferred_name.present?
      @manager_first_name = @manager.preferred_name
    else
      @manager_first_name = @manager.first_name
    end
    unless test_email
      @company = account_creator.company
      @manager = manager
      @account_creator = account_creator

      @email_subject = template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, employee, nil, nil, nil, true)) : I18n.t('mailer.notify_manager_to_provide_information_email.subject')
      @email = template.present? && template.email_to.present? ? ReplaceTokensService.new.replace_tokens(template.email_to, employee) : nil
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, employee) : nil
      @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, employee) : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, employee) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    else
      @company = employee.company
      @email_subject = template.present? && template.subject.present? ? fetch_text_from_html(template.subject) : I18n.t('mailer.notify_manager_to_provide_information_email.subject')
      @email = template.email_to
      @email_desc = template.description
    end
    return unless @company.present? && @company.notifications_enabled

    to_email = fetch_email_from_html(@email)
    template_id = ENV['SG_TEXT_EMAIL']

    if to_email.size > 0
      to_email = to_email.uniq
      email_cc = uniqueEmails(to_email, email_cc)
      email_bcc = uniqueEmails(to_email, email_bcc)
      email_bcc = uniqueEmails(email_cc, email_bcc)

      email_template_obj = {
        company: @company.id,
        emails_to: to_email,
        emails_cc: email_cc.present? ? email_cc : nil,
        emails_bcc: email_bcc.present? ? email_bcc : nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: @email_desc,
        email_subject: fetch_text_from_html(@email_subject),
        email_title: I18n.t('mailer.notify_account_creator_about_manager_form_completion_email.subject'),
        email_button: I18n.t('mailer.notify_account_creator_about_manager_form_completion_email.link_below'),
        button_link: 'https://' + @company.app_domain + '/#/profile/' + @user.id.to_s
      }

      result = SendGridEmailService.new(email_template_obj).perform
    end
  end

  def notify_about_pending_hire_to_subscribers(user, template, test_email=false)
    @user = user
    email_cc = email_bcc = nil
    @company = @user.company
    return unless @company.present? && @company.notifications_enabled
    @team_name = @user.team.name if @user.team && @user.team.name
    @location = @user.location.name if @user.location && @user.location.name

    unless test_email
      email_cc = template.present? && template.cc.present? ? fetch_bcc_cc(template.cc, @user)  : nil
      email_bcc = template.present? && template.bcc.present? ? fetch_bcc_cc(template.bcc, @user) : nil
      email_cc.map!(&:downcase).uniq! if email_cc
      email_bcc.map!(&:downcase).uniq! if email_bcc
    end

    email = template.present? && template.email_to.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.email_to, @user, nil, nil, nil, true)).split(",").map {|c| c.gsub(/[[:space:]]/, '').gsub(/\p{Cf}/,'')}.reject(&:empty?) : nil
    @email_subject = template.present? && template.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, @user, nil, nil, nil, true)) : nil
    @email_desc = template.present? && template.description.present? ? ReplaceTokensService.new.replace_tokens(template.description, @user, nil, nil, nil, true) : nil
    email_cc = uniqueEmails(email, email_cc)
    email_bcc = uniqueEmails(email, email_bcc)
    email_bcc = uniqueEmails(email_cc, email_bcc)
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: email_cc,
      emails_bcc: email_bcc,
      email_attachments: nil,
      template_id: template_id,
      user: nil,
      description: @email_desc.present? ? CGI.unescapeHTML(@email_desc).html_safe : nil,
      email_subject: fetch_text_from_html(@email_subject),
      email_title: I18n.t('mailer.notify_about_pending_hire_to_subscribers.header_top'),
      email_button: I18n.t('mailer.notify_about_pending_hire_to_subscribers.link_below'),
      button_link: 'https://' + @company.app_domain + '/#/pending_hire'
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def notify_user_about_gsuite_account_creation user_id, company
    @user = company.users.find_by(id: user_id)
    return unless @user.present?
    @user_name = @user.display_name
    @company = company

    return unless @company.present?

    body = "Hello #{@user_name},<br><br>Below are important details about your new G-Suite account:<br><br>"
    body += "<b>Email:</b> #{@user.email}<br><b>Password:</b> #{@user.gsuite_initial_password}<br><br>"
    body += "You can complete the set-up of your G-Suite account by clicking <a target=\"_blank\" href=\"https://accounts.google.com/signin\">here.</a><br><br>"
    body += "Congratulations on your new role, <br>#{@company.name}"

    to_email = @user.personal_email.present? ? @user.personal_email : @user.email
    email_bcc = @user.account_creator.try(:email)
    email_bcc = uniqueEmails(to_email, email_bcc)

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: to_email,
      emails_bcc: email_bcc,
      template_id: template_id,
      description: body,
      email_subject: "Your G-Suite account credentials",
      email_title: "Access to your New Email Address"
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def notify_user_about_adfs_account_creation user_id, company
    @user = company.users.find_by(id: user_id)
    return unless @user.present?
    if @user.preferred_name.present?
      @user_first_name = @user.preferred_name
    else
      @user_first_name = @user.first_name
    end
    @company = company

    return unless @company.present?

    body = "Hello #{@user_first_name} #{@user.last_name},<br><br>Below are important details about your new Active Directory account:<br><br>"
    body += "<b>Email:</b> #{@user.email}<br><b>Password:</b> #{@user.active_directory_initial_password}<br><br>"
    body += "You can complete the set-up of your Active Directory account by clicking <a target=\"_blank\" href=\"https://azure.microsoft.com/en-us/services/active-directory/\">here.</a><br><br>"
    body += "Congratulations on your new role, <br>#{@company.name}"

    to_email = @user.personal_email.present? ? @user.personal_email : @user.email
    email_bcc = @user.account_creator.try(:email)
    email_bcc = uniqueEmails(to_email, email_bcc)

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: to_email,
      emails_bcc: email_bcc,
      template_id: template_id,
      description: body,
      email_subject: "Your Active Directory account credentials",
      email_title: "Access to your New Email Address"
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def notify_user_about_learn_upon_account_creation user_id, company, integration, ipassword
    @user = company.users.find_by(id: user_id)
    return unless @user.present?
    if @user.preferred_name.present?
      @user_first_name = @user.preferred_name
    else
      @user_first_name = @user.first_name
    end
    @company = company

    return unless @company.present?

    body = "Hello #{@user_first_name} #{@user.last_name},<br><br>Below are important details about your new LearnUpon account:<br><br>"
    body += "<b>Email:</b> #{@user.email}<br><b>Password:</b> #{ipassword}<br><br>"
    body += "You can complete the set-up of your LearnUpon account by clicking <a target=\"_blank\" href=\"https://#{integration.subdomain}.learnupon.com/\">here.</a><br><br>"
    body += "Congratulations on your new role, <br>#{@company.name}"

    to_email = @user.personal_email.present? ? @user.personal_email : @user.email
    email_bcc = @user.creator.try(:email)
    email_bcc = uniqueEmails(to_email, email_bcc)

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: to_email,
      emails_bcc: email_bcc,
      template_id: template_id,
      description: body,
      email_subject: "Your LearnUpon account credentials",
      email_title: "Access to your New LearnUpon Account"
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def termination_email(termination_email, user=nil, template=nil, test_email=false)
    cc = bcc = nil
    attachments = []
    unless test_email
      id = termination_email.class.name.eql?("UserEmail") ?  termination_email.id : termination_email
      termination_email = UserEmail.find_by(id: id)
      return unless termination_email.present?
      attachments = termination_email.attachments
      @user = termination_email.user
      @company = @user.company
      @email = termination_email.to.compact.present? ?  termination_email.to.compact : termination_email.get_to_email_list
      @description = termination_email.description.present? ? ReplaceTokensService.new.replace_tokens(termination_email.description, @user) : nil
      @subject =  termination_email.subject.present? ? fetch_text_from_html(ReplaceTokensService.new.replace_tokens(termination_email.subject, @user)) : nil

      cc = termination_email.cc.present? ? fetch_bcc_cc(termination_email.cc, @user)  : nil
      bcc = termination_email.bcc.present? ? fetch_bcc_cc(termination_email.bcc, @user) : nil
      email_from = termination_email.from.present? ? termination_email.from : nil

    else
      @user = user
      @company = user.company
      @email = template.email_to
      @description = template.description
      @subject = fetch_text_from_html template.subject
      attachments = template.attachments
    end
    return unless @company.present? && @company.notifications_enabled
    email_cc = uniqueEmails(@email, cc)
    email_bcc = uniqueEmails(@email, bcc)
    email_bcc = uniqueEmails(cc, bcc)

    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: @email,
      email_from: email_from,
      emails_cc: email_cc.present? ? email_cc : nil,
      emails_bcc: email_bcc.present? ? email_bcc : nil,
      email_attachments: attachments,
      template_id: template_id,
      user: @user.id,
      description: @description,
      email_title: nil,
      email_subject: @subject,
      email_button: nil,
      button_link: nil,
      skip_scanning: true
    }
    result = SendGridEmailService.new(email_template_obj).perform

    unless test_email
      termination_email.email_status = UserEmail.statuses[:completed]
      val = result.headers['x-message-id'][0] rescue nil
      termination_email.activity["status"] = 'Processed' if val.present?
      termination_email.message_id = val
      termination_email.to = @email.kind_of?(Array) ? @email : [@email]
      termination_email.sent_at = termination_email.set_send_at
      termination_email.save
    end
  end

  def gsheet_report_email(user, report_name, gsheet_url, company_id)
    try = 0
    begin
      @user = user
      @report_name = report_name
      @gsheet_url = gsheet_url
      @company = Company.find_by(id: company_id)
      return unless @company.present?
      if user.preferred_name.present?
        @first_name = user.preferred_name
      else
        @first_name = user.first_name
      end
      body = I18n.t('mailer.gsheet_report_email.hello', first_name: @first_name) + '<br><br>'
      body += I18n.t('mailer.gsheet_report_email.link_below')
      template_id = ENV['SG_TEXT_EMAIL']
      email_template_obj = {
        company: @company.id,
        emails_to: user.email.present? ? user.email : user.personal_email,
        template_id: template_id,
        description: body,
        email_subject: "#{@report_name} - Available for download",
        email_title: I18n.t('mailer.gsheet_report_email.header_top'),
        email_button: I18n.t('mailer.gsheet_report_email.btn_text'),
        button_link: gsheet_url,
        email_attachments: nil
      }
      result = SendGridEmailService.new(email_template_obj).perform
    rescue ActionView::MissingTemplate => e
      try += 1
      raise if try == 5
      retry
    end
  end

  def csv_report_email(user, report, name, file=nil, excel=false)
    #To add bom into csv to avoid special character misreading
    File.write(file,"\uFEFF" + File.read(file)) if File.extname(file) == ".csv"
    @user = user
    @report_name = name
    @file = file
    @company = Company.find_by(id: report.company_id)

    if excel == true
      @file_name = "#{@report_name}.xlsx"
    else
      @file_name = "#{@report_name}.csv"
    end
    attachments[@file_name] = File.read(file)

    return unless @company.present? && @company.notifications_enabled
    if user.preferred_name.present?
      @first_name = user.preferred_name
    else
      @first_name = user.first_name
    end
    body = I18n.t('mailer.csv_report_email.hello', first_name: @first_name) + '<br><br>' + I18n.t('mailer.csv_report_email.link_below')
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user.email.present? ? user.email : user.personal_email,
      template_id: template_id,
      description: body,
      email_subject: "#{@report_name} - Available for download",
      email_title: I18n.t('mailer.csv_report_email.header_top'),
      report_filename: @file_name,
      report_file: @file,
      skip_scanning: true,
      email_attachments: nil
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def csv_approved_requests_email(user, namee, file=nil, excel=false)
    @user = user
    @report_name = namee
    @file = file
    @company = Company.find_by(id: user.company_id)

    if excel == true
      @file_name = "#{@report_name}.xlsx"
    else
      @file_name = "#{@report_name}.csv"
    end
    attachments[@file_name] = File.read(file)

    return unless @company.present? && @company.notifications_enabled
    if user.preferred_name.present?
      @first_name = user.preferred_name
    else
      @first_name = user.first_name
    end
    body = I18n.t('mailer.csv_report_email.hello', first_name: @first_name) + '<br><br>' + I18n.t('mailer.csv_report_email.link_below')
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user.email.present? ? user.email : user.personal_email,
      template_id: template_id,
      description: body,
      email_subject: "#{@report_name} - Available for download",
      email_title: I18n.t('mailer.csv_report_email.header_top'),
      report_filename: @file_name,
      report_file: @file,
      skip_scanning: true,
      email_attachments: nil
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def document_assigned_email(user, document_name, co_signer=nil, document_due_date)
    begin
      @company = user.company
      return unless @company.present? && @company.notifications_enabled
      @document_name = document_name

      if co_signer.present?
        email = co_signer.email? ? co_signer.email : co_signer.personal_email
        if co_signer.preferred_name.present?
          @first_name = co_signer.preferred_name
        else
          @first_name = co_signer.first_name
        end
        @employee_id = co_signer.id
        @email_body = I18n.t('mailer.document_assigned.cosigner_body', document_name: @document_name, name: user.full_name)
        @user = co_signer

      else
        email = user.email? ? user.email : user.personal_email
        if user.preferred_name.present?
          @first_name = user.preferred_name
        else
          @first_name = user.first_name
        end
        @employee_id = user.id
        @user = user
        @email_body = I18n.t('mailer.document_assigned.user_body', document_name: @document_name, document_due_date: document_due_date)
        @email_body += ("<br/>Due on " + document_due_date.strftime("%b %d, %Y")).html_safe if document_due_date
      end
      template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

      email_template_obj = {
        company: @company.id,
        emails_to: email,
        emails_cc: nil,
        emails_bcc: nil,
        email_attachments: nil,
        template_id: template_id,
        user: @user.id,
        description: I18n.t('mailer.document_assigned.hey', name: @first_name) + '<br/><br/>' + @email_body.html_safe,
        email_subject: I18n.t('mailer.document_assigned.subject'),
        email_title: I18n.t('mailer.document_assigned.header_top'),
        email_button: I18n.t('mailer.document_assigned.link_below'),
        button_link: 'https://' + @company.app_domain + '/#/documents/' +@employee_id.to_s
      }

      result = SendGridEmailService.new(email_template_obj).perform
    rescue StandardError => e
      create_logging(@company, "Document assigned notification - Failure - #{@user&.id}", {error: e.message, result: result.inspect})
    end
  end

  def pre_start_email(user_email, user=nil, test_email=false, template=nil, preview=false)

    unless test_email and !preview
      @user_email = user_email
      unless test_email
        id = @user_email.class.name.eql?("UserEmail") ?  user_email.id : user_email
        @user_email = UserEmail.find_by(id: id)
        return if @user_email.nil? || @user_email.email_status == UserEmail.statuses[:deleted]
        @user = @user_email&.user
      else
        @user = user
      end
      @company = @user&.company
    else
      @user_email = user_email
      @user = user
      @company = user.company
    end
    return unless @company.present? && @company.notifications_enabled && !@user_email&.sent_at.present?

    emails = []

    if preview || test_email
      emails.push @user.email || @user.personal_email
    else
      emails = @user_email.to if @user_email && @user_email.to.present?
      unless emails.present?
        if !@user&.onboard_email
          if @user&.personal_email
            emails.push @user&.personal_email
          else
            emails.push @user.email
          end
        elsif @user&.onboard_email == 'personal'
          emails.push @user.personal_email
        elsif @user&.onboard_email == 'company'
          emails.push @user.email
        elsif @user&.onboard_email == 'both'
          emails.push @user.personal_email
          emails.push @user.email
        end
      end
    end
    emails.map!(&:downcase).uniq! if emails.length != 0

    email_cc = email_bcc = nil
    if preview || !test_email
      @email_subject = @user_email.subject ? ReplaceTokensService.new.replace_tokens(@user_email.subject, @user) : I18n.t('mailer.onboarding_email.welcome_subject', company_name: @user.company.name)
      email_cc = !preview && @user_email.cc.present? ? fetch_bcc_cc(@user_email.cc, @user)  : nil
      email_bcc = !preview && @user_email.bcc.present? ? fetch_bcc_cc(@user_email.bcc, @user) : nil
      email_desc = @user_email.present? && @user_email.description.present? ? ReplaceTokensService.new.replace_tokens(@user_email.description, @user) : nil

    else
      email_desc = ReplaceTokensService.new.replace_dummy_tokens(template.description, @company)
      @email_subject = ReplaceTokensService.new.replace_dummy_tokens(template.subject, @company) ? fetch_text_from_html(template.subject) : I18n.t('mailer.onboarding_email.welcome_subject', company_name: 'Rocketship')
    end

    template_id = ENV['SG_TEXT_EMAIL']

    if test_email && template && template.attachments && !preview
      email_attachments = template.attachments
    elsif @user_email.attachments
      email_attachments = @user_email.attachments
    end
    email_cc = uniqueEmails(emails, email_cc)
    email_bcc = uniqueEmails(emails, email_bcc)
    email_bcc = uniqueEmails(email_cc, email_bcc)
    email_from = !test_email && @user_email.from.present? ? @user_email.from : nil

    email_template_obj = {
      company: @company.id,
      emails_to: emails,
      email_from: email_from,
      emails_cc: email_cc,
      emails_bcc: email_bcc,
      email_attachments: email_attachments,
      template_id: template_id,
      user: @user.id,
      description: email_desc,
      email_subject: fetch_text_from_html(@email_subject),
      email_title: I18n.t('mailer.pre_start.header_top'),
      email_button: I18n.t('mailer.pre_start.button'),
      skip_scanning: true,
      button_link: 'https://' + @company.app_domain + '/#/login'
    }

    result = SendGridEmailService.new(email_template_obj).perform
     if !test_email && !preview
      @user_email.email_status = UserEmail.statuses[:completed]
      @user_email.job_id = nil
      @user_email.sent_at = @user_email.invite_at || Time.now.utc
      val = result.headers['x-message-id'][0] rescue nil
      @user_email.message_id = val
      @user_email.to = emails
      @user_email.activity["status"] = 'Processed' if result.present?
      @user_email.replace_tokens
      @user_email.save
    end
    unless test_email
      SlackNotificationJob.perform_later(@company.id, {
        username: @user.full_name,
        text: I18n.t('slack_notifications.email.welcome', full_name: @user.full_name)
      })

      History.where(user_id: @user.id, email_type: 1).where.not(job_id: nil).first.update(job_id: nil) if History.where(user_id: @user.id, email_type: 1).where.not(job_id: nil).first

      History.create_history({
        company: @company,
        user_id: @user.id,
        description: I18n.t('history_notifications.email.welcome', full_name: @user.full_name),
        attached_users: [@user.id],
        created_by: History.created_bies[:system],
        event_type: History.event_types[:email],
        email_type: History.email_types[:welcome]
      })
    end
  end

  def added_to_workspace_email(user, inviter, workspace)
    return if !user || !inviter || !workspace
    @user = user
    @inviter = inviter
    @workspace = workspace
    @first_name = (user.preferred_name || user.first_name)
    @inviter_first_name = (inviter.preferred_name || inviter.first_name)
    @company = user.company
    return unless @company.present? && @company.notifications_enabled
    @url = 'https://' + @company.app_domain + '/#/workspace/' + @workspace.id.to_s + '/tasks'
    email = user.email.present? ? user.email : user.personal_email

    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: @user.id,
      description: I18n.t('mailer.added_to_workspace_email.body', workspace_name: @workspace.name, url: @url),
      email_subject: "#{@inviter_first_name} has invited you to a Workspace!",
      email_title: I18n.t('mailer.added_to_workspace_email.header_top', inviter_first_name: @inviter_first_name),
      email_button: I18n.t('mailer.added_to_workspace_email.link_below'),
      button_link: @url
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def csv_user_upload_feedback_email(company, user_email , feedback)
    @company = Company.find_by(id: company.id)
    return unless @company.present?
    @title = "Sapling CSV Upload Results"
    @description = feedback
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user_email,
      template_id: template_id,
      description: @description,
      email_subject: @title,
      email_title: @title
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def upload_user_feedback_email(company, user_email , receiver_name, defected_users, users_count, upload_date, file = nil, section_name = '')
    @company = Company.find_by(id: company.id)
    return unless @company.present?
    file_name = nil
    if file
      file_name = "#{company.subdomain}_defective_#{section_name}_#{rand(1000)}.csv"
    end
    team_count = defected_users.count
    uploading_error = team_count > 0
    successly_uploaded = team_count == 0
    description = uploading_error ? I18n.t('mailer.upload_feedback.error_description') : I18n.t('mailer.upload_feedback.success_description')
    member =  uploading_error ?  (team_count > 1 ? 'members' : 'member') : (users_count > 1 ? 'members' : 'member')
    
    upload_details = uploading_error ? I18n.t('mailer.upload_feedback.error_upload_details', success_count: (users_count - defected_users.count), section_name: get_upload_feedback_mapping_section(section_name), defective_count: defected_users.count) : I18n.t('mailer.upload_feedback.success_upload_details', count: users_count, section_name: get_upload_feedback_mapping_section(section_name))
    action_detail = uploading_error ? upload_feedback_error_details(section_name) : upload_feedback_success_details(section_name)

    template_id = ENV['SG_UPLOAD_FEEDBACK_EMAIL']
    subject = uploading_error ? I18n.t('mailer.upload_feedback.error_subject') : I18n.t('mailer.upload_feedback.success_subject')
    begin
      content = upload_data_email_format(successly_uploaded, receiver_name, description, upload_date, upload_details, defected_users, action_detail)
    rescue Exception => e
      content = e.message
    end

    email_template_obj = {
      company: @company.id,
      emails_to: user_email,
      email_subject: subject,
      template_id: template_id,
      receiver_name: receiver_name,
      description: description,
      content: content,
      action_detail: action_detail,
      upload_details: upload_details,
      defected_users: defected_users,
      successly_uploaded: successly_uploaded,
      uploading_error: uploading_error,
      email_type: 'upload_feedback',
      upload_date: upload_date,
      sapling_login: "https://#{@company.domain}",
      defective_users_filename: file_name,
      defective_users_file: file,
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def bulk_document_assignment_failures_email(company, to_email, failures, user_count, requester, document_title)
    @company = company
    return unless @company.present?
    @title = "Failures in Bulk Document Assignment"
    @description = I18n.t('mailer.bulk_document_assignment.description_heading', requester: requester, document_title: document_title, user_count: user_count)
    @description += I18n.t('mailer.bulk_document_assignment.description_sub_heading', user_count: user_count, failed_user_count: failures.count)
    @description += failures.join('<br>')
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: to_email,
      template_id: template_id,
      description: @description,
      email_subject: @title,
      email_title: @title
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def ctus_request_change_email_for_approvers(company_id, from_user_id, to_user_id, requested_user_id, custom_table_name, effective_date, expiry_time)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @from_user = @company.try(:users).find_by(id: from_user_id)
    @to_user = @company.try(:users).find_by(id: to_user_id)
    return unless @to_user.present?
    @requested_user = @company.try(:users).find_by(id: requested_user_id)
    @custom_table_name = custom_table_name
    email = @to_user.email.present? ? @to_user.email : @to_user.personal_email
    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      template_id: template_id,
      user: @requested_user.id,
      description: I18n.t('mailer.custom_tables.approvers_email.description', to_user_name: @to_user.try(:first_name), from_user_name: @from_user.try(:display_name), requested_user_name: @requested_user.try(:display_name), table_name: custom_table_name, effective_date: effective_date, expiry_time: expiry_time),
      email_subject: I18n.t('mailer.custom_tables.approvers_email.subject', user_name: @requested_user.try(:display_name)),
      email_title: I18n.t('mailer.custom_tables.approvers_email.title', user_name: @requested_user.try(:display_name)),
      email_button: I18n.t('mailer.custom_tables.approvers_email.btn_text'),
      button_link: 'https://' + @company.app_domain + '/#/role/' + @requested_user.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def cs_approval_request_change_email_for_approvers(company_id, from_user_id, to_user_id, requested_user_id, custom_table_name, effective_date, expiry_time)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @from_user = @company.try(:users).find_by(id: from_user_id)
    @to_user = @company.try(:users).find_by(id: to_user_id)
    return unless @to_user.present?
    @requested_user = @company.try(:users).find_by(id: requested_user_id)
    @custom_table_name = custom_table_name
    email = @to_user.email.present? ? @to_user.email : @to_user.personal_email
    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      template_id: template_id,
      user: @requested_user.id,
      description: I18n.t('mailer.custom_sections.approvers_email.description', to_user_name: @to_user.try(:first_name), from_user_name: @from_user.try(:display_name), requested_user_name: @requested_user.try(:display_name), table_name: custom_table_name, effective_date: effective_date, expiry_time: expiry_time),
      email_subject: I18n.t('mailer.custom_sections.approvers_email.subject', user_name: @requested_user.try(:display_name)),
      email_title: I18n.t('mailer.custom_sections.approvers_email.title', user_name: @requested_user.try(:display_name)),
      email_button: I18n.t('mailer.custom_sections.approvers_email.btn_text'),
      button_link: 'https://' + @company.app_domain + '/#/profile/' + @requested_user.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def cs_section_approval_request_approved_denied_email_notification(company_id, ctus_created_date, user_id, requester_id, request_state, list, table_name)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @requester = @company.try(:users).find_by(id: requester_id)
    @user = @company.try(:users).find_by(id: user_id)
    return unless (@user.present? && @requester.present?)
    email_add =  @requester.email.present? ? @requester.email : @requester.personal_email

    if request_state == 'approved'
      @title = I18n.t('mailer.custom_sections.approved_request.title')
      @subject = I18n.t('mailer.custom_sections.approved_request.subject')
      action = "approved"
    elsif request_state == 'denied'
      @title = I18n.t('mailer.custom_sections.denied_request.title')
      @subject = I18n.t('mailer.custom_sections.denied_request.subject')
      date = Time.now.strftime('%b %d, %Y')
      @button = I18n.t('mailer.custom_sections.approved_request.btn_text')
      action = "denied"
    elsif request_state == 'requested'
      @title = I18n.t('mailer.custom_sections.delete_request.title')
      @subject = I18n.t('mailer.custom_sections.delete_request.subject')
      date = Time.now.strftime('%b %d, %Y')
      action = "deleted"
    end

    template_id = ENV['SG_APPROVAL_DENIED_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email_add,
      template_id: template_id,
      user: @user.id,
      email_subject: @subject,
      email_title: @title,
      email_type: 'ct_approval_denial',
      requester_name: @requester.try(:first_name),
      user_name: @user.try(:display_name),
      ctus_date: ctus_created_date,
      table_name: table_name,
      approvers: list,
      denied_email: date,
      button_link: 'https://' + @company.app_domain + '/#/',
      action: action
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def cs_approval_request_expired_email_notification(company_id, from_user_id, cs_approval_id, user_id, approvers_email)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @from_user = @company.try(:users).find_by(id: from_user_id)
    @for_user = @company.try(:users).find_by(id: user_id)
    return unless (@from_user.present? && @for_user.present?)
    @custom_section_approval = CustomSectionApproval.with_deleted.where(id: cs_approval_id, user_id: user_id).first
    @email_desc = I18n.t('mailer.custom_tables.expired_request_email.description', from_user_name: @from_user.try(:first_name), created_at: @custom_section_approval.try(:created_at).strftime('%d/%m/%Y'))
    email = @from_user.email.present? ? @from_user.email : @from_user.personal_email
    return unless approvers_email
    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_bcc: approvers_email,
      template_id: template_id,
      user: @from_user,
      description: CGI.unescapeHTML(@email_desc).html_safe,
      email_subject: I18n.t('mailer.custom_tables.expired_request_email.subject'),
      email_title: I18n.t('mailer.custom_tables.expired_request_email.title', user_name: @for_user.try(:display_name)),
      email_button: I18n.t('mailer.custom_tables.expired_request_email.btn_text'),
      button_link: 'https://' + @company.app_domain + '/#/'
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def ctus_request_expired_email_notification(company_id, from_user_id, ctus_id, user_id, approvers_email)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @from_user = @company.try(:users).find_by(id: from_user_id)
    @for_user = @company.try(:users).find_by(id: user_id)
    @custom_table_user_snapshot = CustomTableUserSnapshot.with_deleted.where(id: ctus_id, user_id: user_id).first
    @email_desc = I18n.t('mailer.custom_tables.expired_request_email.description', from_user_name: @from_user.try(:first_name), created_at: @custom_table_user_snapshot.try(:created_at).strftime('%d/%m/%Y'))
    email = @from_user.email.present? ? @from_user.email : @from_user.personal_email
    return unless approvers_email
    template_id = ENV['SG_GENERAL_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email,
      emails_bcc: approvers_email,
      template_id: template_id,
      user: @from_user,
      description: CGI.unescapeHTML(@email_desc).html_safe,
      email_subject: I18n.t('mailer.custom_tables.expired_request_email.subject'),
      email_title: I18n.t('mailer.custom_tables.expired_request_email.title', user_name: @for_user.try(:display_name)),
      email_button: I18n.t('mailer.custom_tables.expired_request_email.btn_text'),
      button_link: 'https://' + @company.app_domain + '/#/'
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def ctus_request_approved_denied_email_notification(company_id, ctus_created_date, user_id, requester_id, request_state, list, table_name, is_destroyed)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @requester = @company.try(:users).find_by(id: requester_id)
    return unless @requester.present?
    @user = @company.try(:users).find_by(id: user_id)
    email_add =  @requester.email.present? ? @requester.email : @requester.personal_email

    if request_state == 'approved'
      @title = I18n.t('mailer.custom_tables.approved_request.title')
      @subject = I18n.t('mailer.custom_tables.approved_request.subject')
      action = "approved"
    elsif request_state == 'requested' && is_destroyed == 'false'
      @title = I18n.t('mailer.custom_tables.denied_request.title')
      @subject = I18n.t('mailer.custom_tables.denied_request.subject')
      denied_date = Time.now.strftime('%b %d, %Y')
      @button = I18n.t('mailer.custom_tables.approved_request.btn_text')
      action = "denied"
    elsif request_state == 'requested' && is_destroyed == 'true'
      @title = I18n.t('mailer.custom_tables.deleted_request.title')
      @subject = I18n.t('mailer.custom_tables.deleted_request.subject')
      denied_date = Time.now.strftime('%b %d, %Y')
      @button = I18n.t('mailer.custom_tables.deleted_request.btn_text')
      action = "deleted"
    end

    template_id = ENV['SG_APPROVAL_DENIED_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: email_add,
      template_id: template_id,
      user: @user.id,
      email_subject: @subject,
      email_title: @title,
      email_type: 'ct_approval_denial',
      requester_name: @requester.try(:first_name),
      user_name: @user.try(:display_name),
      ctus_date: ctus_created_date,
      table_name: table_name,
      approvers: list,
      denied_email: denied_date,
      button_link: 'https://' + @company.app_domain + '/#/',
      action: action
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def download_all_company_documents_email(company_id, download_url, user_email)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @title = I18n.t('mailer.company_documents_download.title', company: @company.name)
    @subject = I18n.t('mailer.company_documents_download.subject', company: @company.name)
    @description = I18n.t('mailer.company_documents_download.description', company: @company.name)
    @download_url = download_url
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user_email,
      template_id: template_id,
      description: @description,
      email_subject: @subject,
      email_title: @title,
      email_button: "Download Compressed Documents",
      button_link: @download_url.gsub(' ', '%20')
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def download_all_profile_pictures_email(company_id, download_url, user_email)
    @company = Company.find_by(id: company_id)
    return unless @company.present?
    @title = I18n.t('mailer.company_profile_pictures_download.title', company: @company.name)
    @subject = I18n.t('mailer.company_profile_pictures_download.subject', company: @company.name)
    @description = I18n.t('mailer.company_profile_pictures_download.description', company: @company.name)
    @download_url = download_url
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user_email,
      template_id: template_id,
      description: @description,
      email_subject: @subject,
      email_title: @title,
      email_button: "Download Compressed Profile Pictures",
      button_link: @download_url.gsub(' ', '%20')
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def api_key_expiration_warning_email(user, type, key_name, expire_in = nil)
    user_email = user.email || user.personal_email
    @company = user.company
    return unless user_email.present? && @company.present?
    @title = I18n.t('mailer.api_key_expiration.title')
    if type == :warning
      @subject = I18n.t('mailer.api_key_expiration.subject1', days_left: expire_in)
      @description = I18n.t('mailer.api_key_expiration.description1', name: key_name, days_left: expire_in )
    else
      @subject = I18n.t('mailer.api_key_expiration.subject2')
      @description = I18n.t('mailer.api_key_expiration.description2', name: key_name)
    end
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: user_email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: user.id,
      description: @description,
      email_subject: @subject,
      email_title: @title,
      email_button: I18n.t('mailer.api_key_expiration.button_text'),
      button_link: "https://#{@company.app_domain}/#/admin/settings/integrations"
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def weekly_new_hires_email(alert, new_hires, recipients, admin_view)
    company = alert.company
    today = Date.today.in_time_zone(company.time_zone).to_date
    cutoff_date = today + 6.days
    if today.month == cutoff_date.month
      title = I18n.t('mailer.new_hires_weekly.title', start: "#{today.strftime('%B')[0..2]} #{today.strftime('%d')}", week_end: "#{cutoff_date.strftime('%d')}")
    else
      title = I18n.t('mailer.new_hires_weekly.title', start: "#{today.strftime('%B')[0..2]} #{today.strftime('%d')}", week_end: "#{cutoff_date.strftime('%B')[0..2]} #{cutoff_date.strftime('%d')}")
    end
    description = I18n.t('mailer.new_hires_weekly.subtitle', count: new_hires.count)
    disable_url = "https://#{company.app_domain}/#/admin/settings/emails?alerts"
    template_id = ENV['SG_HIRES_EMAIL']
    email_to = recipients.pop #set single user as a too and others as bcc
    recipients = nil if recipients.empty?
    email_template_obj = {
      company: company.id,
      emails_to: [email_to],
      emails_bcc: recipients,
      template_id: template_id,
      description: description,
      email_subject: alert.subject,
      email_title: title,
      new_hires: new_hires,
      admin_view: admin_view,
      disable_url: disable_url,
      email_type: "new_hires",
      categories: ["New Hire", "Alert/Update"]
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def weekly_metrics_email(alert, statistics, recipients, admin_view)
    company = alert.company

    today = Date.today.in_time_zone(company.time_zone).to_date
    start_date = (today.at_beginning_of_week-1).at_beginning_of_week
    end_date = start_date.at_end_of_week

    email_title = I18n.t('mailer.weekly_metrics.title', start: "#{start_date.strftime('%B')[0..2]} #{start_date.strftime('%d')}", end: "#{end_date.strftime('%B')[0..2]} #{end_date.strftime('%d')}")

    disable_url = "https://#{company.app_domain}/#/admin/settings/emails?alerts"
    template_id = ENV['SG_WEEKLY_METRICS_EMAIL']
    email_to = recipients.pop #set single user as a too and others as bcc
    recipients = nil if recipients.empty?
    email_template_obj = {
      company: company.id,
      emails_to: [email_to],
      emails_bcc: recipients,
      template_id: template_id,
      email_subject: alert.subject,
      email_title: email_title,
      statistics: statistics,
      admin_view: admin_view,
      disable_url: disable_url,
      email_type: "weekly_metrics",
      categories: ["Weekly Metrics", "Alert/Update"]
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def api_call_error_notification(company, integration_name, action, status, response)
    @company = company
    return unless @company && @company.error_notification_emails.present? && !@company.error_notification_emails.empty?
    @description = %Q(
      <p>Company: #{@company.name}<br>
      Integration: #{integration_name}<br>
      Status code: #{status}<br>
      Result: #{response}<br>
      </p>
    )
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    email_template_obj = {
      company: @company.id,
      emails_to: @company.error_notification_emails,
      emails_cc: nil,
      emails_bcc: nil,
      user: nil,
      email_attachments: nil,
      template_id: template_id,
      description: @description.strip,
      email_subject: I18n.t('mailer.api_call_error_notification.subject', name: @company.name),
      email_title: nil,
      email_button: nil,
      button_link: nil
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def due_documents_email(user, company)
    template_id = ENV['SG_TEXT_EMAIL']
    email_template_obj = {
      company: company.id,
      emails_to: (user.email || user.personal_email),
      template_id: template_id,
      user: user.id,
      description: I18n.t('mailer.overdue_document_email.hey', name: (user.preferred_name || user.full_name)) + '<br/><br/>' + I18n.t('mailer.overdue_document_email.body').html_safe,
      email_subject: I18n.t('mailer.overdue_document_email.subject'),
      email_title: I18n.t('mailer.overdue_document_email.header_top'),
      email_button: I18n.t('mailer.overdue_document_email.link_below'),
      button_link: 'https://' + company.app_domain + '/#/documents/' + user.id.to_s
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def bulk_document_assigned_email(bulk_assigner, assign_time, company)
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']
    @email_body = I18n.t('mailer.bulk_document_assigned.body', assign_time: assign_time)

    email_template_obj = {
      company: company.id,
      emails_to: (bulk_assigner.email || bulk_assigner.personal_email),
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: nil,
      description: I18n.t('mailer.bulk_document_assigned.hey', name: (bulk_assigner.preferred_name || bulk_assigner.first_name)) + '<br/><br/>' + @email_body.html_safe,
      email_subject: I18n.t('mailer.bulk_document_assigned.subject'),
      email_title: I18n.t('mailer.bulk_document_assigned.header_top'),
      email_button: I18n.t('mailer.bulk_document_assigned.link_below'),
      button_link: 'https://' + company.app_domain + '/#/admin/dashboard/transition?open_activities_from_email=true'
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def contact_us(company_id, recipients, description)
    emails_to, emails_bcc = recipients
    email_template_obj = {
      company: company_id,
      emails_to: emails_to,
      emails_cc: nil,
      emails_bcc: emails_bcc,
      email_attachments: nil,
      template_id: ENV['SG_TRANSACTIONAL_TEXT_EMAIL'],
      user: nil,
      description: description,
      email_subject: I18n.t('mailer.contact_us.revenue_opportunity'),
      email_title: nil
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def document_assignment_failed_email(paperwork_request, company, error_message, is_user_associated, is_bulk, impacted_users, job_requester=nil)
    template_id = ENV['SG_DOCUMENT_FAIL_EMAIL']
    requester = paperwork_request&.requester || job_requester

    if is_bulk
      email_subject = I18n.t('mailer.document_failed.subject.bulk')
    else
      email_subject = I18n.t('mailer.document_failed.subject.individual', name: (paperwork_request.user&.preferred_name || paperwork_request.user&.first_name) + ' ' + paperwork_request.user&.last_name)
    end

    email_template_obj = {
      company: company.id,
      emails_to: (requester&.email || requester&.personal_email),
      template_id: template_id,
      user: requester&.id,
      email_subject: email_subject,
      requester_name: (requester&.preferred_name || requester&.first_name) + ' ' + requester&.last_name,
      impacted_users: impacted_users,
      error_message: error_message,
      is_user_associated: is_user_associated,
      is_bulk: is_bulk,
      email_type: 'document_failure'
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def integration_failure_notification(company, error_code, error_message, integration_name)
    template_id = ENV['SG_INTEGRATION_FAILURE']

    email_template_obj = {
      company: company.id,
      emails_to: company.error_notification_emails,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      integration_name: integration_name,
      error_code: error_code,
      error_message: error_message,
      email_type: 'integration_failure',
      email_button: I18n.t('mailer.integration_failure.link_below'),
      button_link: 'https://' + company.app_domain + '/#/login'
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def document_packet_assignment_email(data, company, assignee_user)
    template_id = ENV['SG_DOCUMENT_PACKET_EMAIL']
    email_subject = I18n.t('mailer.document_packet_assigned.subject')
    documents_count = data[:documents_count]
    user_document_link = data[:user_document_link]
    user_profile_picture = data[:user_profile_picture]
    user_initials = data[:user_initials]
    user_name = data[:user_name]
    document_list = data[:document_list]

    email_template_obj = {
      company: company.id,
      emails_to: (assignee_user&.email || assignee_user&.personal_email),
      template_id: template_id,
      email_subject: email_subject,
      documents_count: documents_count,
      user_document_link: user_document_link,
      user_profile_picture: user_profile_picture,
      user_initials: user_initials,
      user_name: user_name,
      document_list: document_list,
      email_type: 'document_packet_assignment'
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def invite_sandbox_user(user, inviter_name)
    company = user.company
    @email_type = 'invite_user'
    return unless company.present? && company.notifications_enabled
    email = user.get_invite_email_address
    raw_token, hashed_token = Devise.token_generator.generate(User, :reset_password_token)
    user.update!(reset_password_token: hashed_token, reset_password_sent_at: Time.now.utc)
    callback_url = CGI.escape("https://#{company.app_domain}/#/reset_password")
    redirect_url = "https://#{company.domain}/api/v1/auth/password/edit?config=default&redirect_url=#{callback_url}&reset_password_token=#{raw_token}&cid=#{company.id}"

    email_template_obj = {
      user: user.id,
      emails_to: email,
      company: company.id,
      full_name: inviter_name,
      button_link: redirect_url,
      sandbox_invite_email: true,
      first_name: user.first_name,
      template_id: ENV['SANDBOX_INVITE_EMAIL'],
      email_type: @email_type,
      email_subject: I18n.t('mailer.invite_user.join', company_name: company.name)
    }

    SendGridEmailService.new(email_template_obj).perform
  end

  def signatory_document_flipped_email(user)
    company = user&.company
    return unless company && company.notifications_enabled

    template_id = ENV['SG_SIGNATORY_DOCUMENT_FLIPPED']
    redirected_url = "https://#{company.domain}/#/admin/dashboard/onboarding"
    email_template_obj = {
      company: company.id,
      emails_to: user.get_email,
      first_name: user.first_name,
      template_id: template_id,
      button_url: redirected_url,
      email_subject: I18n.t('mailer.flipped_document_email.subject'),
      email_type: 'document_flipped_email'
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def sftp_upload_response_email(user, status, report_name)
    company = user&.company
    return unless company.notifications_enabled

    template_id = ENV['SG_GENERAL_EMAIL']
    email_subject =  status ? I18n.t('mailer.sftp_upload_response_email.success_subject') : I18n.t('mailer.sftp_upload_response_email.failed_subject')
    description = status ? I18n.t('mailer.sftp_upload_response_email.success', report_name: report_name ) : I18n.t('mailer.sftp_upload_response_email.failed', report_name: report_name)
    email_template_obj = {
      company: company.id,
      emails_to: user.get_email,
      template_id: template_id,
      description: description,
      email_subject: email_subject,
      email_title: I18n.t('mailer.sftp_upload_response_email.title')
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_loggings_csv_mail(user, options)
    company = Company.find_by(subdomain: 'default')
    return unless company && company.notifications_enabled
    
    email_template_obj = build_loggings_csv_mail_template(user, options.merge!(company: company))
    result = SendGridEmailService.new(email_template_obj).perform
  end

  private

  def build_loggings_csv_mail_template(user, options)
    file_name = "#{options[:file_name]}.csv"
    attachments[options[:file_name]] = File.read(options[:file])
    build_loggings_template_hash(user, options.merge!(file_name: file_name))
  end

  def build_loggings_template_hash(user, options)
    body = "#{ I18n.t('mailer.csv_loggings_email.hello', first_name: user.email)} <br><br> #{I18n.t('mailer.csv_loggings_email.link_below') }"
    {
      company: options[:company].id,
      emails_to: user.email.present? ? user.email : user.personal_email,
      template_id: ENV['SG_TEXT_EMAIL'],
      description: body,
      email_subject: "#{options[:file_name]} - Available for download",
      email_title: I18n.t('mailer.csv_loggings_email.header_top'),
      report_filename: options[:file_name],
      report_file: options[:file],
      skip_scanning: true,
      email_attachments: nil
    }
  end

    def get_task_list
      render_to_string('user_mailer/offboarding_tasks_email_with_activities', layout: false)
    end

    def get_onboarding_task_list
      render_to_string('user_mailer/onboarding_tasks_email_with_activities', layout: false)
    end

    def get_new_tasks_list
      render_to_string('user_mailer/new_tasks_email_with_activities', layout: false)
    end

    def uniqueEmails(src_emails, dest_emails)
      if src_emails.class == String
        src_emails = src_emails.split
      end

      if dest_emails.class == String
        dest_emails = dest_emails.split
      end

      if dest_emails && src_emails
        src_emails.each do |email|
          if dest_emails.include? email
            dest_emails.delete(email)
          end
        end
      end

      dest_emails
    end

    def fetch_email_from_html string
      if string
        txt = Nokogiri::HTML(string).xpath("//*[p]").first
        txt.content.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i) if txt.present?
      end
    end

    def send_to_activity_owner string
      Nokogiri::HTML(string).xpath("//*[@data-name='Activity Owner Email']").size > 0
    end

    def fetch_text_from_html string
      Nokogiri::HTML(string).xpath("//*[p]").first.content rescue " "
    end

    def fetch_bcc_cc string, employee
      cc_mails = []
      cc_mails = fetch_email_from_html(ReplaceTokensService.new.replace_tokens(string, employee))
      cc_mails
    end

    def store_email
      notification_settings = @company&.notifications_enabled || @email_type == 'invite_user'
      return if @company&.account_state != 'active' || @email_type == 'admin_email' || !notification_settings

      if message && message.html_part && message.html_part.body
        message_body = message.html_part.body.decoded
      else
        message_body = message.body.to_s
      end
      if message_body.present?
        email = CompanyEmail.create(
          to: message.to.to_a,
          bcc: message.bcc.to_a,
          cc: message.cc.to_a,
          from: message.from.to_a.first,
          subject: CGI.unescapeHTML(message.subject),
          content: message_body,
          sent_at: Time.now,
          company_id: @company.try(:id)
          )

        message.attachments.each do |attachment|
          filename = attachment.filename
          if @report_filename && @file
            file = @file
          else
            file = "#{Rails.root}/tmp/#{filename}"
          end

          if file.present? && File.exist?(file)
            begin
              UploadedFile.create(
                entity_type: "CompanyEmail",
                entity_id: email.id,
                file: File.open(file),
                type: "UploadedFile::Attachment"
              )
            rescue
              begin
                extension = ""
                strings = filename.split('.')
                extension = strings.last if strings.count > 1
                tempfile = Tempfile.new(['attachment', "." + extension])
                tempfile.binmode
                tempfile.write attachment.body.decoded
                tempfile.rewind
                tempfile.close

                UploadedFile.create(
                  entity_type: "CompanyEmail",
                  entity_id: email.id,
                  file: tempfile,
                  type: "UploadedFile::Attachment"
                )
              rescue Exception => e
                create_logging(@company, 'File Attachment',
                               { result: 'Failed to add attachments in mail', error: e.message, file_name: file,
                                 entity_type: "CompanyEmail", entity_id: email.id })
              end
            end
          else
            create_logging(@company, 'File Attachment',
                           { result: 'Failed to add attachments in mail', file_name: file,
                             entity_type: "CompanyEmail", entity_id: email.id })
          end
        end
      end
    end

    def logging
      @logging ||= LoggingService::GeneralLogging.new
    end

    def upload_data_email_format(successly_uploaded, receiver_name, description, upload_date, upload_details, defected_users, action_detail)
      content = '<table align="center" class="container body-border float-center borderTop radius" style="Margin:0 auto;background:#fefefe;border-collapse:separate;border-radius:4px;border-spacing:0;border-top:4px solid {{customer_brand}};float:none;margin:0 auto;padding:0;text-align:center;vertical-align:top;width:580px">'
      content += '<tbody><tr style="padding:0;text-align:left;vertical-align:top">'
      content += '<td style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#333333;font-family:Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;hyphens:auto;line-height:1.3;margin:0;padding:0;text-align:left;vertical-align:top;word-wrap:break-word">'
      content += '<table class="row" style="border-collapse:collapse;border-spacing:0;display:table;padding:0;position:relative;text-align:left;vertical-align:top;width:100%">'
      content += '<tbody><tr style="padding:0;text-align:left;vertical-align:top">'
      content += '<th class="small-12 large-12 columns first last" style="Margin:0 auto;color:#333333;font-family:Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0 auto;padding:0;padding-bottom:16px;padding-left:24px;padding-right:24px;text-align:left;width:564px">'
      content += '<table style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%"><tbody><tr style="padding:0;text-align:left;vertical-align:top">'
      content += '<th style="Margin:0;color:#333333;font-family:Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.3;margin:0;padding:0;text-align:left">'
      content += '<table class="spacer" style="border-collapse:collapse;border-spacing:0;padding:0;text-align:left;vertical-align:top;width:100%">'
      content += '<tbody><tr style="padding:0;text-align:left;vertical-align:top">'
      content += '<td height="32px" style="-moz-hyphens:auto;-webkit-hyphens:auto;Margin:0;border-collapse:collapse!important;color:#333333;font-family:Roboto,Helvetica,Arial,sans-serif;font-size:32px;font-weight:400;hyphens:auto;line-height:32px;margin:0;mso-line-height-rule:exactly;padding:0;text-align:left;vertical-align:top;word-wrap:break-word">&nbsp;</td></tr></tbody></table>'
      if successly_uploaded
        content += '<center data-parsed="" style="min-width:532px;width:100%"><a href="#"><img src="http://cdn.mcauto-images-production.sendgrid.net/fcd4cfb620541501/61660138-9ed5-49a6-aab9-3c853a1aa770/237x149.png" width="237" height="137" align="center" class="float-center rounded" style="Margin:0 auto;border-radius:8px;clear:both;display:block;float:none;margin:0 auto;max-width:100%;outline:0;text-align:center;text-decoration:none;width:auto"></a></center>'
      else
        content += '<center data-parsed="" style="min-width:532px;width:100%"><a href="#"><img src="http://cdn.mcauto-images-production.sendgrid.net/fcd4cfb620541501/45911ba6-eb94-4331-b3ef-461ce363f581/234x129.png" width="237" height="137" align="center" class="float-center rounded" style="-ms-interpolation-mode:bicubic;Margin:0 auto;border-radius:8px;clear:both;display:block;float:none;margin:0 auto;max-width:100%;outline:0;text-align:center;text-decoration:none;width:auto"></a></center>'
      end
      content += '<br/><br/>'
      if successly_uploaded
        content += '<p class="text-center" style="font-weight: 600 !important;text-align: center !important;">' + I18n.t('mailer.upload_feedback.upload_success_heading')+'</p>'
      else
        content += '<p class="text-center" style="font-weight: 600 !important;text-align: center !important;">' + I18n.t('mailer.upload_feedback.upload_error_heading')+'</p>'
      end
      content += '<p style="margin-top: 30px ;Margin-bottom:10px;color:#33333;font-family:Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:400;line-height:1.5;margin:0;margin-bottom:10px;padding:0;text-align:left">Hi ' +receiver_name+',<br/><br/>'+description+'</p>'
      content += ' <img src="http://cdn.mcauto-images-production.sendgrid.net/fcd4cfb620541501/481edaa5-a18e-4cab-a45f-1935163be64b/16x18.png" width="40" height="40" class="float-center rounded" style="Margin:0 auto;clear:both;margin:0 auto;outline:0;text-align:start;text-decoration:none;width:16px; height:17.7px; margin-right: 7px;"/>'
      if successly_uploaded
        content += '<span style="vertical-align: inherit;">Data uploaded on <b>'+upload_date+'</b></span>'
      else
        content += '<span style="vertical-align: inherit;">Data upload on <b>'+upload_date+'</b></span>'
      end

      content += '<br/><br/>'

      if successly_uploaded
        content += '<img src="http://cdn.mcauto-images-production.sendgrid.net/fcd4cfb620541501/0214f9dc-3e6f-4a0a-ad4e-9669ef66bd6b/22x14.png" width="40" height="40" class="float-center rounded" style="Margin:0 auto;clear:both;margin:0 auto;outline:0;text-align:start;text-decoration:none;width:20px; height:auto; margin-right: 4px;"/><span style="vertical-align: top; margin-bottom: 15px;">'+upload_details+'</span>'

      else
        content += '<img src="http://cdn.mcauto-images-production.sendgrid.net/fcd4cfb620541501/f8a6a953-cbc0-44d8-a062-147ae0ab3a59/22x14.png" width="40" height="40" class="float-center rounded" style="Margin:0 auto;clear:both;margin:0 auto;outline:0;text-align:start;text-decoration:none;width:20px; height:auto; margin-right:4px " /><span style="vertical-align: top;">'+upload_details+'</span>'
        content += '<ul style="margin-left:0px;">'
        defected_users.each do |user|
          if user[:holidays_error]
            content += '<li style="margin-bottom: 8px;font-style: normal;font-weight: normal;font-size: 16px;line-height: 24px;">'+ user[:holidays_error].to_s+'</li>'
          else
            content += '<li style="margin-bottom: 8px;font-style: normal;font-weight: normal;font-size: 16px;line-height: 24px;"> <a href ='+user[:link].to_s+' target=\"_blank\" style="color: #3F1DCB; font-style: normal;font-weight: normal;font-size: 16px;line-height: 24px; text-decoration: none;">'+user[:name].to_s+ '</a> - '+user[:error].to_s+'</li>'
          end
        end
        content += '</ul>'
      end
      content +='<p style="margin-top: 15px;">'+action_detail+'</p></tr></tbody></table></th></tr></tbody> </table></td></tr></tbody></table>'
      content
    end

    def get_email_subject(template, invite_user, tasks_count, secondary_email_subject)
      if template&.subject.present? && !@company.include_activities_in_email
        fetch_text_from_html(ReplaceTokensService.new.replace_tokens(template.subject, invite_user, tasks_count,
                                                                     @activity_owner, nil, true))
      else
        secondary_email_subject
      end
    end

    def get_email_description(template, invite_user, tasks_count)
      if template&.description.present? && !@company.include_activities_in_email
        ReplaceTokensService.new.replace_tokens(template.description, invite_user, tasks_count, @activity_owner)
      else
        get_onboarding_task_list
      end
    end

    def create_logging(company, action, result)
      logging.create(company, action, result)
    end

    def task_emails_log(email_template_obj, email)
      { result: "#{email_template_obj} for email #{email}" }
    end

    def set_entity(workspace)
      type, id = workspace.present? ? [Workspace.name, workspace.id] : [User.name, @user.id]
      { entity_type: type, entity_id: id }
    end

    def over_due_task_log(email_template_obj, email, workspace)
      { email_to: email }.merge!(set_entity(workspace), task_emails_log(email_template_obj, email))
    end

    def upload_feedback_error_details(section_name)
      support_url = 'https://kallidus.zendesk.com/hc/en-us'
      case section_name
      when 'permissions' 
        I18n.t('mailer.upload_feedback.error_details', section: 'team member permissions', section_label: 'Permissions', url: "https://#{@company.domain}/#/admin/settings/roles", action: 'edit', support_url: support_url)
      when 'groups'
        I18n.t('mailer.upload_feedback.error_details', section: 'groups', section_label: 'Groups', url: "https://#{@company.domain}/#/admin/company/groups", action: 'add', support_url: support_url)
       when 'holidays'
        I18n.t('mailer.upload_feedback.error_details', section: 'holidays', section_label: 'Holidays', url: "https://#{@company.domain}/#/admin/company/general", action: 'add', support_url: support_url)
      when 'new_profile', 'existing_profile', 'pto_balance', 'pto_request'
        I18n.t('mailer.upload_feedback.error_details', section: 'team member profiles', section_label: 'People Directory', url: "https://#{@company.domain}/#/people", action: (section_name == 'new_profile' ? 'add' : 'update'), support_url: support_url)    
      end
    end

    def upload_feedback_success_details(section_name)
      support_url = 'https://kallidus.zendesk.com/hc/en-us'
      case section_name
      when 'permissions' 
        I18n.t('mailer.upload_feedback.success_details', section_label: 'Permissions', url: "https://#{@company.domain}/#/admin/settings/roles", action: 'view the updates', support_url: support_url)
      when 'groups'
        I18n.t('mailer.upload_feedback.success_details', section_label: 'Groups', url: "https://#{@company.domain}/#/admin/company/groups", action: 'see your new groups', support_url: support_url)
      when 'holidays'
        I18n.t('mailer.upload_feedback.success_details', section_label: 'Holidays', url: "https://#{@company.domain}/#/admin/company/general", action: 'see your new holidays', support_url: support_url)
      when 'new_profile', 'existing_profile', 'pto_balance', 'pto_request'
        I18n.t('mailer.upload_feedback.success_details', section_label: 'People Directory', url: "https://#{@company.domain}/#/people", action: (section_name == 'new_profile' ? 'to see your new team member profiles' : 'view the updates'), support_url: support_url)  
      end
    end

    def get_upload_feedback_mapping_section(section_name)
      return 'team member permissions' if section_name == 'permissions'
      return 'team member profiles' if %w[new_profile existing_profile pto_balance pto_request].include?(section_name)
      section_name
    end
end
