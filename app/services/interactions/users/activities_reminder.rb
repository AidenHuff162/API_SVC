module Interactions
  module Users
    class ActivitiesReminder < Reminder
      attr_reader :overdue_task_user_ids, :overdue_document_user_ids, :current_time_zones

      def perform
        @overdue_task_user_ids = fetch_overdue_task_user_ids
        @overdue_document_user_ids = fetch_overdue_document_user_ids

        @current_time_zones = []
        ActiveSupport::TimeZone.all.select do |time_zone|
          @current_time_zones.push(time_zone.name) if time_zone.now.hour == 8 && time_zone.now.min.between?(0, 59) && !(time_zone.today.saturday? || time_zone.today.sunday?)
        end

        manage_overdue_individual_task_emails
        manage_overdue_workspace_task_emails
        manage_ovedue_document_emails
      end

      private

      def fetch_overdue_task_user_ids
        tasks = TaskUserConnection.joins(:task)
                  .where("task_user_connections.state = 'in_progress' AND due_date < ? AND tasks.task_type != '4' AND tasks.workstream_id IS NOT NULL", Date.today)
                  .joins(:user)
                  .where("users.current_stage <> #{User.current_stages[:incomplete]} AND (users.outstanding_tasks_count > 0 OR (users.incomplete_paperwork_count + users.incomplete_upload_request_count) > 0 OR users.start_date > ?)", Sapling::Application::ONBOARDING_DAYS_AGO)
        @workspace_ids = tasks.joins(:workspace).where("owner_type = '1'").pluck(:workspace_id)
        ids = tasks.where("owner_type = '0'").pluck(:owner_id)
      end

      def fetch_overdue_document_user_ids
        user_without_due_date = PaperworkRequest.user_without_due_date
        cosigner_ids_without_due_date = PaperworkRequest.cosigner_without_due_date

        user_with_due_date = PaperworkRequest.user_with_due_date
        cosigner_ids_with_due_date = PaperworkRequest.cosigner_with_due_date

        user_doc_ids_without_due_date =  UserDocumentConnection.user_doc_without_due_date
        user_doc_ids_with_due_date = UserDocumentConnection.user_doc_with_due_date

        user_ids = (user_without_due_date + cosigner_ids_without_due_date + user_with_due_date + cosigner_ids_with_due_date + user_doc_ids_without_due_date + user_doc_ids_with_due_date).flatten.uniq
      end

      def fetch_users(user_ids = [])
        User.joins(:company).where(id: user_ids, companies: { deleted_at: nil, time_zone: current_time_zones }).where("state = ? AND current_stage NOT IN (?) AND start_date <= ? ", 'active', [User.current_stages[:incomplete], User.current_stages[:departed]], Date.today)
      end

      def manage_overdue_individual_task_emails
        overdue_task_users = fetch_users(overdue_task_user_ids)
        overdue_task_users.try(:find_each) do |overdue_task_user|
          if can_send_email?(overdue_task_user.company.overdue_notification, DateTime.now.wday)
            send_email_at = DateTime.now.in_time_zone(overdue_task_user.company.time_zone).change(hour: 9).utc
            if send_email_at
              UserMailer.delay_until(send_email_at, queue: 'mailers').overdue_task_email(overdue_task_user.id, overdue_task_user.company_id, nil)
            else
              UserMailer.overdue_task_email(overdue_task_user.id, overdue_task_user.company_id, nil).deliver_now
            end
          end
        end
      end

      def manage_overdue_workspace_task_emails
        workspaces = Workspace.joins(:company).where(id: @workspace_ids,  companies: { deleted_at: nil, time_zone: current_time_zones })
        workspaces.try(:find_each) do |workspace|
          if workspace.get_distribution_emails.any?
            if can_send_email?(workspace.company.overdue_notification, DateTime.now.wday)
              send_email_at = DateTime.now.in_time_zone(workspace.company.time_zone).change(hour: 9).utc
              if send_email_at
                UserMailer.delay_until(send_email_at, queue: 'mailers').overdue_task_email(nil, workspace.company_id, workspace)
              else
                UserMailer.overdue_task_email(nil, workspace.company_id, workspace).deliver_now
              end
            end
          end
        end
      end

      def manage_ovedue_document_emails
        overdue_document_users = fetch_users(overdue_document_user_ids)

        overdue_document_users.try(:find_each) do |overdue_document_user|
          if can_send_email?(overdue_document_user.company.overdue_notification, DateTime.now.wday)
            send_email_at = DateTime.now.in_time_zone(overdue_document_user.company.time_zone).change(hour: 9).utc
            if send_email_at
              UserMailer.delay_until(send_email_at, queue: 'mailers').overdue_document_email(overdue_document_user.id)
            else
              UserMailer.overdue_document_email(overdue_document_user.id).deliver_now
            end
          end
        end
      end
    end
  end
end
