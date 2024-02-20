module Interactions
  module Users
    class PendingHireNotificationEmail
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def perform
        company = user.company

        template = EmailTemplate.where(email_type: "new_pending_hire", company_id: company.id).first

        if company.new_pending_hire_emails?
            UserMailer.notify_about_pending_hire_to_subscribers(user, template).deliver_now!
        end
      end
    end
  end
end
