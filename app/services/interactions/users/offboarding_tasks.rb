module Interactions
  module Users
    class OffboardingTasks
      attr_reader :user, :task_ids, :company

      def initialize(user, task_ids)
        @user = user
        @task_ids = task_ids
        @company = Company.where(id: user.company_id).first
      end

      def perform
        tuc = TaskUserConnection.joins(:task).where.not(tasks: {task_type: Task.task_types['jira']}).where.not(tasks: {task_type: Task.task_types['service_now']}).where(id: task_ids).where("task_user_connections.owner_type = 0 AND (task_user_connections.before_due_date <= ? OR (task_user_connections.before_due_date IS NULL AND task_user_connections.state != ? ))", Date.today,'draft').order(:owner_id)
        task_user_ids = tuc.pluck(:owner_id)
        counts = task_user_ids.each_with_object(Hash.new(0)) { |id, counts| counts[id] += 1 }
        owner_tasks = Hash[tuc.group('owner_id').pluck('task_user_connections.owner_id, array_agg(task_id)')]
        tasks_due_dates = Hash[tuc.pluck(:id, :due_date)]
        task_user_ids.uniq!
        task_user_ids.each do |id|
          if id && company.offboarding_activity_notification
            invited = id
            if company.include_activities_in_email
              activities = {}
              activities[:tasks] = Task.where(id: owner_tasks[id]).reorder(:workstream_id, :deadline_in)
              tucs = tuc.where(owner_id: id, task_id: activities[:tasks].ids)
              activities[:tuc_tokens] = Hash[tucs.pluck(:id, :token)]
              activities[:task_tuc] = Hash[tucs.pluck(:task_id, :id)]

              activities[:tdd] = tasks_due_dates
              UserMailer.delay.offboarding_tasks_email_with_activities(user, invited, counts[id], activities)
            else
              UserMailer.offboarding_tasks_email(user, invited, counts[id], "individual").deliver_later
            end
          end
        end
        send_workspace_tasks_emails
        SlackNotificationJob.perform_later(@user.company_id, {
          username: @user.company.name,
          text: I18n.t("slack_notifications.email.offboarding_tasks", tasks_count: task_user_ids.count, first_name: @user.first_name, last_name: @user.last_name)
        })
        History.create_history({
          company: @user.company,
          description: I18n.t("history_notifications.email.offboarding_tasks", tasks_count: task_user_ids.count, first_name: @user.first_name, last_name: @user.last_name),
          attached_users: [@user.id],
          created_by: History.created_bies[:system],
          event_type: History.event_types[:email]
        })
      end

      def send_workspace_tasks_emails
        tuc = TaskUserConnection.where(id: task_ids).where("owner_type = 1 AND (task_user_connections.before_due_date <= ? OR (task_user_connections.before_due_date IS NULL AND task_user_connections.state != ? ))", Date.today,'draft').order(:workspace_id)
        workspace_ids = tuc.pluck(:workspace_id)
        counts = workspace_ids.each_with_object(Hash.new(0)) { |id, counts| counts[id] += 1 }
        workspace_tasks = Hash[tuc.group('workspace_id').pluck('workspace_id, array_agg(task_id)')]
        tasks_due_dates = Hash[tuc.pluck(:id, :due_date)]
        workspace_ids.uniq!
        workspaces = Workspace.where(id: workspace_ids)
        workspace_ids.each do |id|
          workspace = workspaces.find_by(id: id)
          workspace_user = User.new(preferred_name: workspace.name, email: workspace.associated_email, id:workspace.id)
          if company.include_activities_in_email
            activities = {}
            activities[:tasks] = Task.where(id: workspace_tasks[id]).reorder(:workstream_id, :deadline_in)
            tucs = tuc.where(workspace_id: id, task_id: activities[:tasks].ids)
            activities[:tuc_tokens] = Hash[tucs.pluck(:id, :token)]
            activities[:task_tuc] = Hash[tucs.pluck(:task_id, :id)]

            activities[:tdd] = tasks_due_dates
            UserMailer.offboarding_tasks_email_with_activities(user, workspace_user, counts[id], activities, "workspace").deliver_now
          else
            UserMailer.offboarding_tasks_email(user, workspace_user, counts[id], "workspace").deliver_now
          end
        end
      end
    end
  end
end
