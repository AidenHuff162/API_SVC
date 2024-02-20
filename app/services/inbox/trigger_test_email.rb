module Inbox
  class TriggerTestEmail < ApplicationService
    include ActionView::Helpers::SanitizeHelper

    def initialize(current_user, email_template_params)
      @current_user = current_user
      @current_company = current_user.company
      @email_template_params = email_template_params
      @email_template = EmailTemplate.new(email_type: email_template_params[:email_type])
    end

    def call
      prepare_email
      if DEFAULT_NOTIFICATION_TEMPLATES.include?(email_template.email_type)
        send("trigger_#{email_template.email_type}")
      else
        UserMailer.custom_email(nil, email_template, current_user, true).deliver_now!
      end
    end

    private

    attr_reader :current_user, :email_template, :current_company, :email_template_params, :replace_token

    def trigger_manager_form
      UserMailer.notify_account_creator_about_manager_form_completion_email(current_user.id, nil, nil, email_template, true).deliver_now!
    end

    def trigger_new_manager_form
      UserMailer.notify_manager_to_provide_information_email(current_user, nil, email_template, true).deliver_now!
    end

    def trigger_new_manager
      UserMailer.buddy_manager_change_email(current_user.id, nil, nil, nil, email_template, true, 'Manager').deliver_now!
    end

    def trigger_new_buddy
      UserMailer.buddy_manager_change_email(current_user.id, nil, nil, nil, email_template, true, 'Buddy').deliver_now!
    end

    def trigger_onboarding_activity_notification
      UserMailer.onboarding_tasks_email(nil, nil, nil, nil, nil, nil, nil, nil, current_user, email_template, true).deliver_now!
    end

    def trigger_transition_activity_notification
      UserMailer.new_tasks_email(nil, nil, nil, nil, nil, nil, nil, nil, current_user, email_template, true).deliver_now!
    end

    def trigger_offboarding_activity_notification
      UserMailer.offboarding_tasks_email(current_user, nil, nil, nil, email_template, true).deliver_now!
    end

    def trigger_preboarding
      UserMailer.preboarding_complete_email(current_user, email_template, nil, nil, true).deliver_now!
    end

    def trigger_offboarding
      UserMailer.termination_email(nil, current_user, email_template, true).deliver_now!
    end

    def trigger_document_completion
      UserMailer.send_document_completion_email(current_user, nil, current_user.company, true, email_template).deliver_now!
    end

    def trigger_invitation
      UserMailer.custom_email(nil, email_template, current_user, true).deliver_now!
    end

    def trigger_welcome_email
      UserMailer.custom_email(nil, email_template, current_user, true).deliver_now!
    end

    def trigger_new_pending_hire
      UserMailer.notify_about_pending_hire_to_subscribers(current_user, email_template, true).deliver_now!
    end

    def trigger_start_date_change
      UserMailer.start_date_change_email(current_user, true).deliver_now!
    end

    def trigger_invite_user
      UserMailer.invite_user(current_user, nil, false, email_template, true).deliver_now!
    end

    def prepare_email
      email_template.subject = '[Test Email] ' +  replace_token_service.replace_dummy_tokens(email_template_params[:subject], current_company)
      email_template.description = replace_token_service.replace_dummy_tokens(email_template_params[:description], current_company).gsub(/\n/, '').gsub('<p><br></p>' , '<br>')
      email_template.email_to = current_user.email ? current_user.email : current_user.personal_email
      email_template.cc = strip_tags(email_template_params[:cc])
      email_template.bcc = strip_tags(email_template_params[:bcc])
      email_template.attachment_ids = email_template_params[:attachment_ids]
      email_template.schedule_options = email_template_params[:schedule_options]
    end

    def replace_token_service
      replace_token ||= ReplaceTokensService.new
    end
  end
end