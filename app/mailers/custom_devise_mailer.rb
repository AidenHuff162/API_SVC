class CustomDeviseMailer < Devise::Mailer
  include Roadie::Rails::Automatic

  helper :application
  include Devise::Controllers::UrlHelpers

  def reset_password_instructions(record, token, opts={})
    @resource = record
    @company = Company.new
    @admin_user = false
    @redirect_url = opts[:redirect_url]
    if record.class.to_s == 'User'
      @company = record.company
      @company_name = @company.name
      @first_name = @resource.first_name
      @logo_company = @company.logo
      @domain_company = @company.domain
      @email_color_company = @company.email_color || '#3F1DCB'
    else
      @company = nil
      @admin_user = true
      @company_name = ''
      @first_name = 'admin'
      @logo_company = 'reset-pass-admin'
      @domain_company = ActionMailer::Base.default_url_options[:host] + ':3000'
      @email_color_company = 'black'
      company_with_email = "security@#{ENV['DEFAULT_HOST']}"
    end

    @token = token
    @client_config = opts[:client_config]

    email = opts[:email] || (record.email.present? ? record.email : record.personal_email)
    from_email = @logo_company == 'reset-pass-admin' ? company_with_email : from_email(@company)
    subdomain = @company.subdomain rescue 'rocketship'

    host = "#{subdomain}.#{ENV['DEFAULT_HOST']}"

    email_template_obj = {
      admin_user: @admin_user,
      company: @company&.id,
      emails_to: email.to_s,
      email_from: from_email.to_s,
      email_title: I18n.t('mailer.reset_password_instructions.header_top'),
      email_subject: I18n.t('devise.mailer.reset_password_instructions.subject'),
      template_id: ENV['SG_TEXT_EMAIL'],
      description: 'Hey ' +@first_name + '!<br/><br/>' + I18n.t('devise.mailer.reset_password_instructions.request_reset_link_msg') + '<br/><br/>'+I18n.t('mailer.devise.password_change_instruction')+'<br/><br/>',
      email_button: 'Change my password',
      email_type: 'reset_password',
      button_link: edit_password_url(@resource, reset_password_token: @token, config: @client_config,
                                                protocol: 'https', host: host)
    }

    SendGridEmailService.new(email_template_obj).perform
  end

protected
  def from_email(company)
    company = Company.find_by_id(company.id) if company.present?
    SetUrlOptions.call(company, ActionMailer::Base.default_url_options)
    if company
      "#{company.sender_name} <#{company.subdomain}@#{ENV['DEFAULT_HOST']}>"
    else
      'admin'
    end
  end
end
