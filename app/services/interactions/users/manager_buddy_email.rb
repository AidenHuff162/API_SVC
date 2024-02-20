module Interactions
  module Users
    class ManagerBuddyEmail
      attr_reader :employee, :buddy_manager, :buddy_manager_name, :template_type

      def initialize(employee, buddy_manager, buddy_manager_name, template_type, send_email_at = nil)
        @employee = employee
        @buddy_manager = buddy_manager
        @buddy_manager_name = buddy_manager_name
        @template_type = template_type
        @send_email_at = send_email_at
      end

      def perform
        company = employee.company
        if ((company.manager_emails? && template_type == 'new_manager') || (company.buddy_emails? && template_type == 'new_buddy')) && employee.email_enabled?
          buddy_manager_email = buddy_manager.email || buddy_manager.personal_email

          if @send_email_at
            UserMailer.delay_until(@send_email_at, queue: 'mailers').buddy_manager_change_email(employee.id, buddy_manager.id, buddy_manager_email, template_type, nil, false, buddy_manager_name)
          else
            UserMailer.buddy_manager_change_email(employee.id, buddy_manager.id, buddy_manager_email, template_type, nil, false, buddy_manager_name).deliver_now!
          end

          begin
            SlackNotificationJob.perform_later(@employee.company_id, {
              username: @employee.company.name,
              text: I18n.t("slack_notifications.email.manager_or_buddy_assigned", manager_or_buddy_full_name: @buddy_manager.full_name, type: @buddy_manager_name, employee_full_name: @employee.full_name)
            })
            History.create_history({
              company: @employee.company,
              user_id: @employee.id,
              description: I18n.t("history_notifications.email.manager_or_buddy_assigned", manager_or_buddy_full_name: @buddy_manager.full_name, type: @buddy_manager_name, employee_full_name: @employee.full_name),
              attached_users: [@buddy_manager.id, @employee.id],
              created_by: History.created_bies[:system],
              event_type: History.event_types[:email]
            })
          rescue Exception => e
          end
        end
      end
    end
  end
end
