module Interactions
  module Activities
    class Assign
      attr_reader :invite_user, :task_id, :document, :email_count, :is_onboarding

      def initialize(invite_user, task_id = nil, document = nil, is_onboarding = false)
        @invite_user = invite_user
        @task_id = task_id
        @document = document
        @email_count = 0
        @is_onboarding = is_onboarding
      end

      def perform
        company = invite_user&.company
        return unless company.present?

        if company.onboarding_activity_notification || company.offboarding_activity_notification || company.transition_activity_notification
          if task_id
            tuc = get_task_user_connnections(false)
            employee_email_tasks = email_new_tasks
            employee_workspace_email_tasks = email_new_workspace_tasks
            owner_tasks, tasks_due_dates = tasks_owner_due_date(tuc)
            process_type = get_process_type(task_id[0], company)
            employee_email_tasks.each do |eet|
              name, email, emp_id, email_notification = eet[0], eet[1], eet[2], eet[3]
              tasks_count = tuc.where(owner_id: emp_id, user_id: invite_user.id, owner_type: 0).count
              send_activities_email(name, email, emp_id, tasks_count, tuc, owner_tasks, tasks_due_dates, "individual") if email_notification && tasks_count > 0 && send_email_flag(emp_id) > 0
            end
            employee_workspace_email_tasks.each do |eet|
              name, email, workspace_id = eet[0], eet[1], eet[2]
              if email.present?
                tasks_count = tuc.where(workspace_id: workspace_id, user_id: invite_user.id).count
                send_activities_email(name, email, invite_user.id, tasks_count, tuc, owner_tasks, tasks_due_dates, "workspace", workspace_id) if tasks_count > 0
              end
            end

            history_text = I18n.t("history_notifications.email.new_activity", tasks_count: email_count, first_name: invite_user.first_name, last_name: invite_user.last_name).html_safe
            slack_text = I18n.t("slack_notifications.email.new_activity", tasks_count: email_count, first_name: invite_user.first_name, last_name: invite_user.last_name).html_safe
          elsif document_present(document)
            name, email, tasks_count, emp_id = document_emails(invite_user.id)
            send_activities_email(name, email, emp_id, tasks_count, nil, nil, nil) if tasks_count > 0 && send_email_flag(emp_id) > 0
            history_text = I18n.t("history_notifications.email.new_activity", tasks_count: 1, first_name: invite_user.first_name, last_name: invite_user.last_name).html_safe
            slack_text = I18n.t("slack_notifications.email.new_activity", tasks_count: 1, first_name: invite_user.first_name, last_name: invite_user.last_name).html_safe
          end
          begin
            SlackNotificationJob.perform_later(invite_user.company_id, {
              username: company.name,
              text: slack_text
            }) if slack_text.present?
            History.create_history({
              company: company,
              description: history_text,
              attached_users: [invite_user.id],
              created_by: History.created_bies[:system],
              event_type: History.event_types[:email]
            }) if history_text.present?
          rescue Exception => e
          end
        end
      end

      private

      def send_activities_email(name, email, emp_id, tasks_count, tuc, owner_tasks, tasks_due_dates, task_type, workspace_id=nil , uoc=nil, owner_outcomes=nil)
        activities_flag = (task_id || document_present(document)) ? true : false
        email_user = User.find_by_email(email) || User.find_by_personal_email(email)
        start_date_flag = email_user.start_date <= Date.today rescue false
        owner_flag = invite_user.id == emp_id
        if activities_flag
          if invite_user.company.include_activities_in_email
            if task_id
              if task_type == "individual"
                activities = populate_new_tasks(emp_id, tuc, owner_tasks, tasks_due_dates)
              elsif task_type == "workspace"
                workspace = invite_user.company.workspaces.find_by(id: workspace_id)
                return if workspace.nil?
                return if workspace.get_distribution_emails.empty?
                activities = populate_workspace_new_tasks(emp_id, tuc, owner_tasks, tasks_due_dates, workspace_id)
              end
            elsif document_present(document)
              activities = populate_new_documents(emp_id)
            else
              activities = populate_activities_invited(emp_id, tuc, uoc, owner_tasks, tasks_due_dates)
            end
            return if !is_onboarding && !invite_user.company.transition_activity_notification && !invite_user.company.send_notification_before_start && !start_date_flag
            data = set_email_data(invite_user, name, email, tasks_count, activities_flag, owner_flag, task_type, workspace_id, activities)
            select_email_type(data, invite_user.company.include_activities_in_email)
          else
            return if !is_onboarding && !invite_user.company.transition_activity_notification && !invite_user.company.send_notification_before_start && !start_date_flag
            data = set_email_data(invite_user, name, email, tasks_count, activities_flag, owner_flag, task_type, workspace_id)
            select_email_type(data, invite_user.company.include_activities_in_email)
          end
          @email_count+=1 if start_date_flag && !invite_user.company.send_notification_before_start
        end
      end

      def select_email_type(data, include_activities_in_email)
        process_tasks = Hash.new
        if task_id
          task_ids = data[:activities] && data[:activities][:tasks] ? data[:activities][:tasks].pluck(:id) : task_id
          tasks_per_process_type = get_tasks_per_process_type(task_ids, invite_user.company)
          tasks_per_process_type.each do |process_type, task_array|
            if include_activities_in_email && data[:activities]&.[](:tasks)
              process_tasks[:tasks] = data[:activities][:tasks].where(id: task_array) 
              process_tasks[:task_tuc] = data[:activities][:task_tuc].select do |task, _tuc| 
                tasks_per_process_type[process_type].include?(task) 
              end
              process_tasks[:tuc_tokens] = data[:activities][:tuc_tokens].select do |tuc, _token| 
                process_tasks[:task_tuc].values.include?(tuc) 
              end
              process_tasks[:tdd] = data[:activities][:tdd].select do |tuc, _date| 
                process_tasks[:task_tuc].values.include?(tuc) 
              end
              process_tasks[:documents] = data[:activities][:documents] if data[:activities][:documents]
            end 
            send_email_as_per_process_type(data, include_activities_in_email, process_type, process_tasks)
          end
        else
          send_email_as_per_process_type(data, include_activities_in_email, data[:task_ids].first, process_tasks)
        end  
      end

      def get_task_user_connnections(flag)
        if flag
          invite_user.task_user_connections.where("owner_type = 0 AND (before_due_date <= ? OR before_due_date IS NULL)", Date.today).where.not(owner_id: invite_user.id).order(:owner_id)
        else
          TaskUserConnection.joins(task: :workstream).where(task_id: task_id, state: "in_progress").where.not(tasks: {task_type: "4"}).where("task_user_connections.user_id = ? AND (before_due_date <= ? OR before_due_date IS NULL)", invite_user.id, Date.today)
        end
      end

      def tasks_owner_due_date(tuc)
        return Hash[tuc.group('owner_id').pluck('task_user_connections.owner_id, array_agg(task_id)')],
          Hash[tuc.pluck(:id, :due_date)]
      end

      def email_new_tasks
        owner_ids = TaskUserConnection.joins(task: :workstream).where(user_id: invite_user.id, task_id: task_id, owner_type: 0).pluck(:owner_id)
        company = @invite_user.company
        if company
          owners = company.users.where(id: owner_ids)
        end
        owners.pluck('first_name, COALESCE(email, personal_email), users.id, email_notification')
      end

      def email_new_workspace_tasks
        workspace_ids = TaskUserConnection.includes(:workspace).joins(task: :workstream).where(user_id: invite_user.id, task_id: task_id, owner_type: 1).pluck(:workspace_id)
        workspaces = @invite_user.company.workspaces.where(id: workspace_ids)
        workspaces.map{|v| [v[:name], v.get_distribution_emails, v[:id]]}
      end

      def document_emails(emp_id)
        user = User.find emp_id
        tasks_count = 0
        if document && document.keys && document.keys.count
          tasks_count = 1
        else
          tasks_count = get_document_titles(emp_id).count if emp_id == invite_user.id
        end
        [ user.first_name, user.email || user.personal_email, tasks_count, emp_id ]
      end

      def get_task_tokens(tucs)
        return Hash[tucs.pluck(:id, :token)], Hash[tucs.pluck(:task_id, :id)]
      end

      def paperwork_request_count(emp_id)
        Document.where(id: PaperworkRequest.where("user_id = ? AND state = ? AND paperwork_packet_id IS NULL", emp_id, "assigned").pluck(:document_id)).pluck(:title)
      end

      def document_upload_request_count(emp_id)
        DocumentUploadRequest.where(id: UserDocumentConnection.where(user_id: emp_id).pluck(:document_upload_request_id)).pluck(:title)
      end

      def paperwork_packet_count(emp_id)
        PaperworkPacket.where(id: PaperworkRequest.where("user_id = ? AND paperwork_packet_id IS NOT NULL", emp_id).pluck(:paperwork_packet_id)).pluck(:name)

      end

      def get_document_titles(emp_id)
        paperwork_request_count(emp_id) + document_upload_request_count(emp_id) + paperwork_packet_count(emp_id)
      end

      def populate_activities_invited(emp_id, tuc, uoc, owner_tasks, tasks_due_dates)
        activities = {}

        activities[:tasks] = Task.where(id: owner_tasks[emp_id]).reorder(:workstream_id, :deadline_in)
        tucs = tuc.where(owner_id: emp_id, task_id:activities[:tasks].ids)

        activities[:tuc_tokens], activities[:task_tuc] = get_task_tokens(tucs)
        activities[:tdd] = tasks_due_dates

        activities[:documents] = get_document_titles(emp_id) if emp_id == invite_user.id

        activities
      end

      def populate_new_documents(emp_id)
        activities = {}
        if document[:doc_type] == 'paperwork_request'
          activities[:documents] = Document.where(id: PaperworkRequest.where(id: document[:doc_id]).pluck(:document_id)).pluck(:title)
        elsif document[:doc_type] == 'document_upload_request'
          activities[:documents] = DocumentUploadRequest.where(id: UserDocumentConnection.where(user_id: emp_id, id: document[:doc_id] ).pluck(:document_upload_request_id)).pluck(:title)
        elsif document[:doc_type] == 'paperwork_packet'
          activities[:documents] = PaperworkPacket.where(id: PaperworkRequest.where("user_id = ? AND paperwork_packet_id = ?", emp_id, document[:doc_id]).pluck(:paperwork_packet_id)).pluck(:name)
        end if document && document.keys && document.keys.count
        activities
      end

      def send_email_flag(emp_id)
        current_stages = [User.current_stages[:incomplete], User.current_stages[:departed]]
        User.where("id = ? AND state <> 'inactive' AND current_stage NOT IN (?) ", emp_id, current_stages).count
      end

      def document_present(document)
        document && document.keys && document.keys.present?
      end

      def populate_new_tasks(emp_id, tuc, owner_tasks, tasks_due_dates)
        activities = {}
        activities[:tasks] = Task.where(id: owner_tasks[emp_id], workspace_id: nil).reorder(:workstream_id)
        tucs = tuc.where(owner_id: emp_id, task_id:activities[:tasks].ids)

        activities[:tuc_tokens], activities[:task_tuc] = get_task_tokens(tucs)
        activities[:tdd] = tasks_due_dates
        activities
      end

      def populate_workspace_new_tasks(emp_id, tuc, owner_tasks, tasks_due_dates, workspace_id)
        activities = {}
        activities[:tasks] = Task.where(workspace_id: workspace_id, id: owner_tasks[emp_id] ).reorder(:workstream_id)
        tucs = tuc.where(workspace_id: workspace_id, task_id:activities[:tasks].ids)

        activities[:tuc_tokens], activities[:task_tuc] = get_task_tokens(tucs)
        activities[:tdd] = tasks_due_dates
        activities
      end

      def set_email_data(invite_user, name, email, tasks_count, activities_flag, owner_flag, task_type, workspace_id, activities = nil)
        {
          task_ids: task_id,
          invite_user: invite_user, 
          name: name, 
          email: email, 
          tasks_count: tasks_count, 
          activities_flag: activities_flag, 
          owner_flag: owner_flag, 
          task_type: task_type,
          workspace_id: workspace_id,
          activities: activities 
        }
      end

      def get_process_type(task_id, company)
        task_workstream = company.workstreams.joins(:tasks).where('tasks.id = ?', task_id).take
        task_workstream.present? ? task_workstream.process_type.try(:name).try(:downcase) : 'transition'
      end

      def get_tasks_per_process_type(task_ids, company)
        tasks_per_process_type = Hash.new { |hash, key| hash[key] = Array.new }
        task_ids.each do |task|
          tasks_per_process_type[get_process_type(task, company)].push(task)
        end
        tasks_per_process_type
      end

      def send_offboarding_tasks_email(invite_user, process_tasks)
        tucs = get_task_user_connnections(false)
        offboarding_tasks = process_tasks[:tasks] ? tucs.where(task_id: process_tasks[:tasks].ids) : tucs
        Interactions::Users::OffboardingTasks.new(invite_user, offboarding_tasks.ids).perform
      end

      def send_email_as_per_process_type(data, include_activities_in_email, process_type, process_tasks)
        company = data[:invite_user].company
        tasks_count = process_tasks[:tasks] ? process_tasks[:tasks].count : data[:tasks_count]
        activities = data[:activities]&.[](:tasks) ? process_tasks : data[:activities]
        if include_activities_in_email
          if (process_type == 'onboarding' && company.onboarding_activity_notification)
            UserMailer.onboarding_tasks_email_with_activities(
              data[:invite_user], 
              data[:name], 
              data[:email], 
              tasks_count,
              activities,
              data[:activities_flag], 
              data[:owner_flag], 
              data[:task_type]
            ).deliver_now!
          elsif (process_type == 'offboarding' && company.offboarding_activity_notification)
            send_offboarding_tasks_email(data[:invite_user], process_tasks)
          elsif (['onboarding', 'offboarding'].exclude?(process_type) && company.transition_activity_notification)
            UserMailer.new_tasks_email_with_activities(
              data[:invite_user], 
              data[:name], 
              data[:email], 
              tasks_count,
              activities,
              data[:activities_flag], 
              data[:owner_flag], 
              data[:task_type]
            ).deliver_now!
          end
        else
          if (process_type == 'onboarding' && company.onboarding_activity_notification)
            UserMailer.onboarding_tasks_email(
              data[:invite_user], 
              data[:name], 
              data[:email], 
              tasks_count,
              data[:activities_flag], 
              data[:owner_flag], 
              data[:task_type],
              data[:workspace_id]
            ).deliver_now!
          elsif (process_type == 'offboarding' && company.offboarding_activity_notification)
            send_offboarding_tasks_email(data[:invite_user], process_tasks)
          elsif (['onboarding', 'offboarding'].exclude?(process_type) && company.transition_activity_notification)
            UserMailer.new_tasks_email(
              data[:invite_user], 
              data[:name], 
              data[:email], 
              tasks_count,
              data[:activities_flag], 
              data[:owner_flag], 
              data[:task_type], 
              data[:workspace_id]
            ).deliver_now!
          end
        end
      end

    end
  end
end
