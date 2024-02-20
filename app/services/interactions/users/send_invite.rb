module Interactions
  module Users
    class SendInvite
      attr_reader :id, :sandbox_invite, :inviter_name, :send_invitaiton, :people_page

      def initialize(id, send_invitaiton=true, people_page=false, sandbox_invite=false, inviter_name='')
        @id = id
        @send_invitaiton = send_invitaiton
        @people_page = people_page
        @sandbox_invite = sandbox_invite
        @inviter_name = inviter_name
      end

      def perform
        user = User.find(id)
        user_details = {}
        integration = user.company.integration_instances.find_by(api_identifier: "google_auth", state: :active)
        google_auth_enable = false

        if integration && integration.active? && !people_page
          google_auth_enable = true
          description = I18n.t('mailer.onboarding_email.welcome_note', start_date: user.start_date, company_name: user.company.name)
          subject = I18n.t('mailer.onboarding_email.welcome_subject', company_name: user.company.name)
          invite = user.invites.take
          unless invite
            invite = Invite.create!(user_id: user.id, subject: subject, description: description)
            LoggingService::GeneralLogging.new.create(user.company, 'Invitation token created during resend invitation', {result: "Invitation token #{invite.token} generated for user id #{user.id} during resend invitation"})
          end

          if Rails.env.production?
            user_details = "https://#{user.company.app_domain}/#/invite/#{invite.token}"
          else
            user_details = "http://#{user.company.app_domain}/#/invite/#{invite.token}"
          end

        else
          user_details = nil
        end
        send_notifications(user)
        if sandbox_invite
          UserMailer.invite_sandbox_user(user, inviter_name).deliver_now!
        else
          UserMailer.invite_user(user, user_details, google_auth_enable).deliver_now! if send_invitaiton
        end
      end

      private

      def send_notifications(user)
        message = I18n.t("history_notifications.email.user_invited", full_name: user.full_name)
        History.create_history({
          company: user.company,
          user_id: user.id,
          description: message,
          attached_users: [user.id],
          event_type: History.event_types[:email],
          email_type: History.email_types[:invite]
        })
        SlackNotificationJob.perform_later(user.company_id, {
          username: user.full_name,
          text: message
        })
      end
    end
  end
end
