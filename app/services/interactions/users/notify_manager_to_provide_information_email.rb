module Interactions
  module Users
    class NotifyManagerToProvideInformationEmail
      attr_reader :employee, :manager

      def initialize(employee, manager, profile_template_id)
        @employee = employee
        @manager = manager
        @profile_template = ProfileTemplate.find_by(id: profile_template_id)
      end

      def perform
        company = @employee.company

        begin
          if company.present? && is_new_hire_information_required?(company)
            if company.new_manager_form_emails && @employee.email_enabled? && collect_from_manager_field_exists?(company)
              manager_email = @manager.email || @manager.personal_email
              @employee.is_form_completed_by_manager = 'incompleted'

              UserMailer.notify_manager_to_provide_information_email(@employee, @manager).deliver_now!

              History.create_history({
                company: company,
                user_id: @employee.id,
                description: I18n.t("history_notifications.manager_form.sent", manager_full_name: @manager.full_name, employee_full_name: @employee.full_name),
                attached_users: [@manager.id, @employee.id],
                created_by: History.created_bies[:system],
                event_type: History.event_types[:email]
              })
              SlackNotificationJob.perform_later(company.id, {
                username: company.name,
                text: I18n.t("slack_notifications.manager_form.sent", manager_full_name: @manager.full_name, employee_full_name: @employee.full_name)
              })
            end

            @employee.save!
          end
        rescue Exception => e
          LoggingService::GeneralLogging.new.create(company, 'Email - NotifyManagerToProvideInformationEmail', {error: e.message}) 
        end
      end

      def is_new_hire_information_required?(company)
        company.custom_fields.find_by(collect_from: 2).present? || company.prefrences['default_fields'].select { |prefrence| prefrence['collect_from'] == 'manager' }.present?
      end

      def collect_from_manager_field_exists?(company)
        if @profile_template.present?
          profile_template_custom_field_connections = @profile_template.profile_template_custom_field_connections
          if profile_template_custom_field_connections.any?
            profile_template_custom_field_connections.each do |cfc|
              if cfc.custom_field && cfc.custom_field.collect_from == 'manager'
                return true
              elsif cfc.default_field_id && company.prefrences && company.prefrences['default_fields']
                prefrence_field = company.prefrences['default_fields'].select {|default_field| default_field['id'] == cfc.default_field_id}
                if prefrence_field.count == 1 && prefrence_field[0]['collect_from'].downcase == 'manager'
                  return true
                end
              end
            end
          end
        end
        return false
      end
    end
  end
end
