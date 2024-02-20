class SendUserEmailsJob < ApplicationJob
  queue_as :schedule_email
  def perform(user_id, action, send = nil, schedule_email_ids=nil, profile_template_id=nil, flatfile_rehire = false, draft_tasks = nil, current_company_id = nil)
    begin
      user = User.find_by(id: user_id)
      return if user.nil?
      if send == false
        user.destroy_all_incomplete_emails
        logging.create(user.company, 'Destroy incomplete Email', {result: "Destroy all incomplete emails for user id #{user_id} during #{action}"})           
      elsif send == true
        #For offboarding destroy existing scheduled emails
        destroy_scheduled_emails(user, action, schedule_email_ids) if action == 'offboarding'
        invite_at = nil
        count = 0
        if action == 'onboarding'
          invite = user.invites.create
          logging.create(user.company, 'Invitation token created while Onboarding Email with feature flag', {result: "Invitation token #{invite.token} generated for user id #{user_id} during #{action}"})
        end
        user.user_emails.where(email_status: UserEmail::statuses[:incomplete]).order(:invite_at).each do |user_email|
          user_email.assign_template_attachments(user_email.template_attachments)
          if action == 'onboarding' && (count == 0 || user_email.invite_at.nil?) #send manager buddy email and okta one login account based on this email
            invite_at = user_email.invite_at
            count +=1
          end
          user_email.invite_at.nil? && !flatfile_rehire ? user_email.completed! : user_email.scheduled!   
          user_email.send_user_email(nil, flatfile_rehire)
        end
        logging.create(user.company, 'Schedule Email', {result: "Schedule incomplete emails for user id #{user_id} during #{action}"})
        if action == 'onboarding'
          begin
            invite.update(invite_at: invite_at) unless invite_at.nil?
            if !profile_template_id.nil?
              profile_template_id = profile_template_id.to_i
            end
            
            Activities::UpdateDraftTask.new.perform(current_company_id, user_id, draft_tasks)
            user.initiate_notifications_after_onboarding(invite_at, profile_template_id)
          rescue Exception => e
            logging.create(user.company, 'New Hire Onboarding Notification', {result: "Failed User (#{user.id}) - Onboarding notifications", error: e.message})
          end
        end
      end
    rescue Exception => e
      logging.create(user.company, 'Schedule Email', {result: "Failed #{action} schedule emails for user #{user_id}", error: e.message})           
    end
  end

  def destroy_scheduled_emails(user, action, email_ids)
    user_emails = user.user_emails.where(id: email_ids)
    if user_emails.present?
      logging.create(user.company, 'Destroyed Scheduled Email', {result: "Destroyed Scheduled emails #{user_emails.map(&:id)} for user id #{user.id} before #{action}"})           
      user_emails.destroy_all
    end
  end

  private
  def logging
    @logging ||= LoggingService::GeneralLogging.new
  end
end
