class TimeOffMailer < ApplicationMailer
  after_action :store_email

  def send_request_to_manager_for_approval_denial time_off_request_id, action_performer, comment_id, manager, options = {}
    time_off_request = PtoRequest.find_by(id: time_off_request_id)
    comment = time_off_request.comments.find_by(id: comment_id) if time_off_request.present?
    return if time_off_request.blank? || (comment_id.present? && comment.blank?)
    comment.check_for_mail = options[:check_for_mail] if comment.present?
    initialize_instance_variables time_off_request, comment, manager
    ld_user = { key: @company.name }
    return unless @company.notifications_enabled
    token_users
    updated_existing_request = options[:request_time_modified].present?
    action_performer_name = (action_performer.preferred_name || action_performer.first_name) if action_performer

    set_user_and_email time_off_request, manager
    @unlimited_policy = time_off_request.pto_policy.unlimited_policy
    @show_approve_deny = (@email == manager.get_present_email && time_off_request.status == "pending")

    out_of_office = get_out_of_office_users(time_off_request, manager) if @show_approve_deny

    title = set_title updated_existing_request, action_performer_name
    subject = set_subject updated_existing_request,
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    manager.set_hash_id if @show_approve_deny && manager.hash_id.nil?

    email_template_obj = create_email_object subject, title, action_performer, time_off_request, out_of_office, template_id

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_auto_update_email time_off_request
    initialize_instance_variables time_off_request, nil, nil
    @company = time_off_request.user.company
    return unless @company.notifications_enabled
    pto_policy = @pto_request.pto_policy
    @policy_name = pto_policy.try(:name)
    @request_length = time_off_request.get_request_length
    @user = time_off_request.user
    if time_off_request.denied?
      subject = I18n.t('mailer.time_off.timeoff_expired')
      title = I18n.t('mailer.time_off.timeoff_expired_title')
      header = I18n.t('mailer.time_off.timeoff_expired_and_denied_header')
    else
      subject = I18n.t('mailer.time_off.timeoff_expired_approved')
      title = I18n.t('mailer.time_off.timeoff_expired_title_approved')
      header = I18n.t('mailer.time_off.timeoff_expired_and_approved_header')
    end
    email = @user.get_present_email
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    email_template_obj = { company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: title,
      user: @user.id,
      pto_date: header,
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      show_approve_deny: false,
      policy_name: @policy_name,
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def time_off_custom_alert(custom_alert, custom_alert_receiver, time_off_request)
    initialize_instance_variables time_off_request, time_off_request.comments.try(:first), nil
    @company = @user.company
    token_users
    @user_first_name = @user.preferred_name || @user.first_name
    @alert_header = @user_first_name.to_s + custom_alert.body.to_s
    @alert_title = custom_alert.title
    @email_color = @company.email_color
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    email_template_obj = { company: @company.id,
      emails_to: (custom_alert_receiver.email || custom_alert_receiver.personal_email),
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: custom_alert.subject,
      customer_logo: @company.logo,
      email_title: @alert_header,
      user: @user.id,
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      show_approve_deny: false,
      policy_name: @policy_name,
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def set_user_and_email time_off_request, manager
    if @comment.present?
      if @comment.check_for_mail.present?
        if time_off_request.user == @comment.commenter
          @user = @comment.commenter
          @email = manager.get_present_email
        else
          @user = time_off_request.user.manager
          @email = time_off_request.user.get_present_email
        end
      else
        @user = time_off_request.user
        @email = manager.get_present_email
      end
    else
        @user = time_off_request.user
        @email = manager.get_present_email
    end
    @employee = time_off_request.user
  end

  def token_users
    if @comment != nil
      @description= @comment.description
      return unless @description
      while @description.include? "USERTOKEN" do
        @comment.mentioned_users.each do |m|
          string_to_replace = "USERTOKEN[" + m.to_s + "]"
          user = @company.users.find_by_id(m)
          @description = @description.sub string_to_replace, user.display_first_name
        end
      end
    end
  end

  def send_email_to_nick time_off_request, comment, manager
    initialize_instance_variables time_off_request, comment,  manager
    @company = manager.company
    return unless @company.notifications_enabled
    pto_policy = @pto_request.pto_policy
    @policy_name = pto_policy.try(:name)
    @request_length = time_off_request.get_request_length
    @manager_first_name = @manager.preferred_name || @manager.first_name
    subject = get_email_subject_based_for_managers_response(time_off_request)
    @user = time_off_request.user
    email = @user.get_present_email
    # send_email(email, subject)
    if @pto_request.status == 'approved'
      title = I18n.t('mailer.time_off.approved_heading')
      subheader = I18n.t('mailer.time_off.approved_sub_heading', manager_name: @manager.display_name)
      subheader += "</br>" + I18n.t('mailer.time_off.details', tense: 'are')
    else
      title = I18n.t('mailer.time_off.denied_heading')
      subheader = I18n.t('mailer.time_off.denied_sub_heading', manager_name: @manager.display_name)
      subheader += '</br>' + I18n.t('mailer.time_off.details', tense: 'were')
    end
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    email_template_obj = { company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: title,
      user: @user.id,
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      show_approve_deny: false,
      nick_approved_denied: true,
      approved: @pto_request.status == 'approved',
      manager_name: @manager.display_name,
      policy_name: @policy_name,
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_overdue_requests_mail time_off_request, manager
    if time_off_request.comments.present?
      comment = time_off_request.comments[-1].description
    else
      comment = nil
    end
    @company = manager.company
    return unless @company.notifications_enabled
    @user_first_name = time_off_request.user.preferred_name || time_off_request.user.first_name
    initialize_instance_variables time_off_request, comment, manager
    subject = I18n.t('mailer.time_off.pending_request', employee_name: time_off_request.user.display_name)
    email = @manager.get_present_email
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    approve_url = ""
    deny_url = ""
    manager.set_hash_id if manager.hash_id.nil?
    if Rails.env.production?
      review_details_url = "https://#{@company.app_domain}/#/review_pto/#{time_off_request.hash_id}?user_id=#{@manager.hash_id}"
    else
      review_details_url = "http://#{@company.app_domain}/#/review_pto/#{time_off_request.hash_id}?user_id=#{@manager.hash_id}"
    end
    email_template_obj = { company: @company.id,
      emails_to: email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: I18n.t('mailer.time_off.overdue_pto_request_header_top', employee_preferred_full_name: @user_first_name),
      user: time_off_request.user.id,
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      button_cta: I18n.t('mailer.time_off.review_in_sapling'),
      review_details_url: review_details_url,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      show_approve_deny: true,
      policy_name: @policy_name,
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_email_to_manager_of_auto_approved_request time_off_request_id, action_performer, manager, options = {}
    time_off_request = PtoRequest.find_by(id: time_off_request_id)
    return if time_off_request.blank?
    initialize_instance_variables time_off_request, nil,  manager
    return unless @company.notifications_enabled
    @updated_existing_request = options[:request_time_modified].present?
    @action_performer_name = (action_performer.preferred_name || action_performer.first_name ) if action_performer
    if @updated_existing_request
      subject =  I18n.t('mailer.time_off.modified_auto_approved_subject', employee_name: time_off_request.user.display_name)
      title = I18n.t('mailer.time_off.modified_auto_approved')
    else
      subject = I18n.t('mailer.time_off.auto_approved_subject', employee_name: time_off_request.user.display_name)
      title = I18n.t('mailer.time_off.auto_approved')
    end
    set_user_and_email time_off_request, manager
    @user_first_name = @user.preferred_name || @user.first_name
    @user_full_name = @user.display_name
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    email_template_obj = { company: @company.id,
      emails_to: @email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: title,
      user: time_off_request.user.id,
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      policy_name: @policy_name,
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_email_to_manager_on_request_cancel time_off_request, comment, manager
    initialize_instance_variables time_off_request, comment,  manager
    return unless @company.notifications_enabled
    token_users
    @user_first_name = @user.preferred_name || @user.first_name
    @user_full_name = @user.display_name
    request_time = time_off_request.begin_date <= @company.time.to_date ? 'Historical' : 'Upcoming'
    subject =  I18n.t('mailer.time_off.cancelled_request_subject', employee_name: @user_first_name, request_time: request_time)
    set_user_and_email time_off_request, manager
    template_id = ENV['SG_PTO_GENERAL_EMAIL']
    email_template_obj = { company: @company.id,
      emails_to: @email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: I18n.t('mailer.time_off.cancelled_request', employee_name: @user_first_name, request_time: request_time),
      user: @user.id,
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      pto_comment: @comment.present? ? @description : nil,
      sapling_link: sapling_link(time_off_request),
      template_id: template_id,
      pto_email: true,
      show_approve_deny: false,
      policy_name: @policy_name,
    }

    result = SendGridEmailService.new(email_template_obj).perform
  end

  def send_negative_balance_alert custom_email_alert, user, pto_request=nil
    @company = user.company
    @subject =  custom_email_alert.subject
    @title =  custom_email_alert.title
    @desc = ReplaceTokensService.new.replace_tokens(custom_email_alert.body, (pto_request.present? ? pto_request.user : user), nil, nil, nil, false, pto_request)
    template_id = ENV['SG_TRANSACTIONAL_TEXT_EMAIL']

    email_template_obj = {
      company: @company.id,
      emails_to: user.get_present_email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: template_id,
      user: nil,
      description: @desc,
      email_subject: custom_email_alert.subject,
      email_title: I18n.t('mailer.time_off.negative_balance_header'),
      email_button: I18n.t('mailer.time_off.view_in_sapling'),
      button_link: "https://#{@company.app_domain}/#/time_off/#{pto_request.present? ? pto_request.user_id : user.id}"
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  private

  def get_email_subject_based_for_managers_response pto
    subject = ''
    if pto.updation_requested
      pto.status == 'approved' ? I18n.t('mailer.time_off.updated_request_approved') : I18n.t('mailer.time_off.update_request_denied')
    else
      pto.status == 'approved' ? I18n.t('mailer.time_off.approved') : I18n.t('mailer.time_off.denied')
    end
  end

  def initialize_instance_variables time_off_request, comment, manager
    @user = time_off_request.user
    @pto_request = time_off_request
    pto_policy = @pto_request.pto_policy
    @policy_type = pto_policy.try(:policy_type).try(:titleize)
    @policy_name = pto_policy.try(:name)
    @request_length = time_off_request.get_request_length
    @comment = comment
    @manager = manager
    @company = time_off_request.user.company
    if @company.date_format == "dd/MM/yyyy"
      @format = "%d/%m/%y"
    else
      @format = "%m/%d/%y"
    end
  end

  def get_request_length request, pto_policy
    if request.partial_day_included
      return "#{request.get_total_balance} hour(s), partial day" if pto_policy.tracking_unit == "hourly_policy"
      return "#{request.get_total_balance/pto_policy.working_hours} day(s), half day" if pto_policy.tracking_unit == "daily_policy"
    else
      return "#{request.get_total_balance} hour(s), full day(s)" if pto_policy.tracking_unit == "hourly_policy"
      return "#{request.get_total_balance/pto_policy.working_hours} day(s)" if pto_policy.tracking_unit == "daily_policy"
    end
  end

  def get_remaining_balance request, pto_policy
    return "#{(request.assigned_pto_policy.balance - request.get_total_balance).round(1)} hour(s)" if pto_policy.tracking_unit == "hourly_policy"
    return "#{((request.assigned_pto_policy.balance - request.get_total_balance)/pto_policy.working_hours).round(1)} day(s)" if pto_policy.tracking_unit == "daily_policy"
  end

  def store_email
    if message && message.html_part && message.html_part.body
      message_body = message.html_part.body.decoded
    else
      message_body = message.body.to_s
    end
    CompanyEmail.create(
      to: message.to.to_a,
      bcc: message.bcc.to_a,
      cc: message.cc.to_a,
      from: message.from.to_a.first,
      subject: message.subject,
      content: message_body,
      sent_at: Time.now,
      company_id: @company.id
      ) if message_body.present?
  end

  def get_out_of_office_users time_off_request, manager
    user_ids = manager.managed_user_ids - [time_off_request.user_id]
    range = time_off_request.begin_date..time_off_request.end_date
    ooo = []
    PtoRequest.where(user_id: user_ids, status: [PtoRequest.statuses[:pending], PtoRequest.statuses[:approved]]).each do |pto|
      if range.overlaps? (pto.begin_date..pto.end_date)
        ooo << { ooo_avatar: pto.user.picture, ooo_initials: pto.user.initials, ooo_name: pto.user.display_name, ooo_date: TimeConversionService.new(@company).format_pto_dates(pto.begin_date, pto.end_date)}
      end
    end
    return ooo
  end

  def set_title  updated_existing_request, action_performer_name
    if @comment.present? and @pto_request.comments.present? and @comment.check_for_mail.present?
      if @comment.commenter == @manager
        return I18n.t('mailer.time_off.manager_comment', employee_first_name: @comment.commenter.display_name)
      else
        return I18n.t('mailer.time_off.comment', employee_first_name: @comment.commenter.display_name)
      end
    else
      if updated_existing_request
        return I18n.t('mailer.time_off.updated_pto_request_header_top', employee_preferred_full_name: action_performer_name)
      else
        return I18n.t('mailer.time_off.new_pto_request_header_top', employee_preferred_full_name: action_performer_name)
      end
    end
  end

  def set_subject updated_existing_request, manager
    if updated_existing_request
      return @comment.present? ? (@comment.check_for_mail.present? ? I18n.t('mailer.time_off.subject_comment', employee_name: @comment.commenter.display_name) : I18n.t('mailer.time_off.modified_pto_request', employee_name: @pto_request.user.display_name) ) : I18n.t('mailer.time_off.modified_pto_request', employee_name: @pto_request.user.display_name)
    else
      return I18n.t('mailer.time_off.new_pto_request', employee_name: @pto_request.user.display_name)
    end
  end

  def create_email_object subject, title, action_performer, time_off_request, out_of_office, template_id
    approver_hash_id = @company.users.where('email = ? OR personal_email = ? ', @email, @email).take.try(:hash_id)
    approve_url = ""
    deny_url = ""
    if Rails.env.production?
      review_details_url = "https://#{@company.app_domain}/#/review_pto/#{@pto_request.hash_id}?user_id=#{approver_hash_id}"
    else
      review_details_url = "http://#{@company.app_domain}/#/review_pto/#{@pto_request.hash_id}?user_id=#{approver_hash_id}"
    end
    { company: @company.id,
      emails_to: @email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      email_subject: subject,
      customer_logo: @company.logo,
      email_title: title,
      user: action_performer.present? ? action_performer.id : @comment.try(:commenter).try(:id),
      pto_date: TimeConversionService.new(@company).format_pto_dates(time_off_request.begin_date, time_off_request.get_end_date),
      pto_type: @policy_type,
      pto_length: @request_length,
      leftover_balance: @unlimited_policy ? nil : time_off_request.calculate_leftover_balance,
      pto_comment: @comment.present? ? @description : nil,
      button_cta: "Approve Time Off",
      review_details_url: review_details_url,
      sapling_link: sapling_link(time_off_request),
      out_of_office: {
        team_members: out_of_office
      },
      template_id: template_id,
      pto_email: true,
      show_approve_deny: @show_approve_deny,
      policy_name: @policy_name,
    }
  end

  def sapling_link time_off_request, user=nil
    "https://#{@company.app_domain}/#/time_off/#{time_off_request.present? ? time_off_request.user_id : user.id }?date=#{time_off_request.try(:begin_date)}"
  end
end
