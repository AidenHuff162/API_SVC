class CustomTableMailer < ApplicationMailer
  require 'sendgrid-ruby'
  include SendGrid
  after_action :store_email

  def send_power_update_confirmation_email current_user_first_name, current_user_email, company_id, company_name, data_count, table_name
    email_template_obj = {
      company: company_id,
      emails_to: current_user_email,
      emails_cc: nil,
      emails_bcc: nil,
      email_attachments: nil,
      template_id: ENV['SG_TEXT_ONLY_EMAIL'],
      user: nil,
      description: get_power_update_confirmation_content(current_user_first_name, data_count, company_name, table_name).html_safe,
      email_subject: I18n.t('mailer.power_update.subject'),
      email_title: I18n.t('mailer.power_update.subject'),
      email_button: nil,
      button_link: nil
    }
    result = SendGridEmailService.new(email_template_obj).perform
  end

  private

  def get_power_update_confirmation_content current_user_first_name, data_count, company_name, table_name
    I18n.t('mailer.power_update.body', employee_name: current_user_first_name, user_count: data_count, company_name: company_name, table_name: table_name)
  end

end
