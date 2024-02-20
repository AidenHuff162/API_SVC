module Interactions
  module Users
    class NotifyAccountCreatorAboutManagerFormCompletionEmail
      attr_reader :employee, :manager, :account_creator

      def initialize(employee, manager, account_creator)
        @employee = employee
        @manager = manager
        @account_creator = account_creator
      end

      def perform
        company = @employee.company

        begin
          if company.present? && company.manager_form_emails? && @employee.email_enabled?
            template = EmailTemplate.where(email_type: "manager_form", company_id: company.id).first
            UserMailer.delay_for(10.seconds, queue: 'mailers').notify_account_creator_about_manager_form_completion_email(@employee.id, @account_creator, @manager, template)
          end

          History.create_history({
            company: company,
            user_id: @employee.id,
            description: I18n.t("history_notifications.manager_form.completed", manager_full_name: @manager.full_name, employee_full_name: @employee.full_name),
            attached_users: [@manager.id, @employee.id],
            created_by: History.created_bies[:system],
            event_type: History.event_types[:email]
          })
          SlackNotificationJob.perform_later(company.id, {
            username: company.name,
            text: I18n.t("slack_notifications.manager_form.completed", manager_full_name: @manager.full_name, employee_full_name: @employee.full_name)
          })
        rescue Exception => e
        end
      end
    end
  end
end
