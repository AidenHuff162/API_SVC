module Api
  module V1
    class TaskUserConnectionsController < ApiController
      load_and_authorize_resource except: [:update_inactive_tasks, :show_inactive_task, :undo_delete_task, :hard_delete_task, :show_task]
      load_and_authorize_resource :user, except: [:update_inactive_tasks, :show_inactive_task, :update]
      authorize_resource only: [:update_inactive_tasks, :show_inactive_task]

      before_action :authenticate_user!, only: [:paginated, :index, :update_task_user_connection_on_manager_change]
      before_action :task_platform_visibility, only: [:paginated, :index, :get_tasks_count, :assign]

      before_action only: [:update] do
        ::PermissionService.new.checkAccessibilityForOthers('task', current_user, params[:employee_id] || current_user.id) if params['complete_task']
      end

      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      include ManageUserUpdate

      def assign
        interaction = if params[:non_onboarding] && assign_params.present?
                        Interactions::TaskUserConnections::Assign.new(@user,
                                                                      assign_params,
                                                                      false,
                                                                      true,
                                                                      params[:due_dates_from],
                                                                      params[:agent_id],
                                                                      false,
                                                                      params[:created_through_onboarding])
                      elsif !params[:owner_id] && assign_params.present?
                        Interactions::TaskUserConnections::Assign.new(@user,
                                                                      assign_params,
                                                                      false,
                                                                      false,
                                                                      params[:due_dates_from],
                                                                      params[:agent_id],
                                                                      false,
                                                                      params[:created_through_onboarding])
                      else
                        Interactions::TaskUserConnections::Destroy.new(params[:owner_id],
                                                                       assign_params)
                      end

        interaction.perform
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      def index
        collection = TaskUserConnectionsCollection.new(collection_params)
        respond_with collection.results,
        each_serializer: TaskUserConnectionSerializer::Base
      end

      def update
        old_state = @task_user_connection.state

        old_date = @task_user_connection.due_date rescue nil
        new_date = task_user_connection_params['due_date'].to_date rescue nil

        old_owner_id = @task_user_connection.owner_id

        if task_user_connection_params[:agent_id].present?
          @task_user_connection.completed_by_method = TaskUserConnection.completed_by_methods[:user]
        end
        @task_user_connection.update(task_user_connection_params)

        user = @task_user_connection.user
        owner = @task_user_connection.owner

        if user&.stage_onboarding?
          user.onboarding!
        end
        is_due_date_changed = old_date.present? && new_date.present? && old_date != new_date
        if old_owner_id != owner&.id || is_due_date_changed
          task = @task_user_connection.task rescue nil
          if task.present? && user.present?
            create_slack_notification(task, user, is_due_date_changed, owner)
          end
        end

        if params[:is_owner_reassigning] && (@task_user_connection.before_due_date.nil? || is_assign_date_in_past?(user))
          UserMailer.task_reassign_email(@task_user_connection).deliver_later!
        end
        respond_with @task_user_connection,
          get_user_count: params[:get_user_count],
          get_owner_count: params[:get_owner_count],
          is_owner_view: params[:is_owner_view],
          company_id: current_company.id,
          tasks_page: params[:tasks_page],
          serializer: TaskUserConnectionSerializer::UpdateWithCount, scope: { workstream_filter: params["workstream_filter"]}

        log_event(old_state)
      end

      def create_slack_notification(task, user, is_due_date_changed, owner)
        task.owner_id = owner.id
        task = task.as_json
        message_content = {
          type: "assign_task",
          tasks: [task],
          due_dates_from: @task_user_connection.from_due_date
        }
        if task['time_line'].eql?('immediately')
          SlackIntegrationJob.perform_async("Task_Assign", {user_id: user.id, current_company_id: user.company_id, message_content: message_content}, is_due_date_changed)
        elsif task['time_line'].eql?('later')
          Sidekiq::ScheduledSet.new.find_job(@task_user_connection.job_id)&.delete
          notify_on = @task_user_connection.try(:before_due_date).try(:to_time)
          notify_on = notify_on.in_time_zone(user.company.time_zone) if notify_on
          job_id = SlackIntegrationJob.perform_at(notify_on, "Task_Assign", {user_id: user.id, current_company_id: user.company_id, message_content: message_content}, is_due_date_changed) if notify_on && @task_user_connection.before_due_date >= Date.today
          @task_user_connection.update(job_id: job_id) if job_id
        end
      end

      def update_inactive_tasks
        user = current_company.users.find_by(id: params[:user_id])
        if user
          task_user_connection = user.task_user_connections.with_deleted.find_by_id(params[:id])
        end
        if task_user_connection.nil?
          render json: { error: 'The task you were looking for does not exist' }
        else
          task_user_connection.update(task_user_connection_params)
          respond_with task_user_connection,
            get_user_count: params[:get_user_count],
            get_owner_count: params[:get_owner_count],
            is_owner_view: params[:is_owner_view],
            company_id: current_company.id,
            tasks_page: params[:tasks_page],
            serializer: TaskUserConnectionSerializer::UpdateWithCount
        end
      end

      def show_task
        if params[:view_task]
          user = current_company.users.find_by(id: params[:employee_id])
          if user
            respond_with user.task_user_connections.with_deleted.find_by_id(params[:id]),
              serializer: TaskUserConnectionSerializer::ViewTask
          else
            respond_with status: 404
          end
        end
      end

      def update_task_user_connection_on_manager_change
        reassign_manager_activities(params[:previous_manager_id], params[:user_id], Task.task_types[:manager], params[:manager_id])
      end

      def show
        if params[:view_task]
          respond_with @task_user_connection,
            serializer: TaskUserConnectionSerializer::ViewTask
        else
          respond_with @task_user_connection,
            is_owner_view: params[:is_owner_view]
        end
      end

      def show_inactive_task
        user = current_company.users.find_by_id(params[:employee_id])
        if user
          task_user_connection = user.task_user_connections.with_deleted.find_by_id(params[:id])
          respond_with task_user_connection,
            get_user_count: params[:get_user_count],
            get_owner_count: params[:get_user_count_owner_count],
            is_owner_view: params[:is_owner_view],
            tasks_page: params[:tasks_page],
            company_id: current_company.id,
            serializer: TaskUserConnectionSerializer::UpdateWithCount
        else
          respond_with status: 404
        end
      end

      def paginated
        collection_results = TaskUserConnectionsCollection.new(collection_params)
                      .results
                      .includes(:user, :sub_task_user_connections, user: [:profile_image])
        task_counts = get_tasks_count_against_workflow
        respond_with collection_results,
                     each_serializer: TaskUserConnectionSerializer::ProfileTasks,
                     is_owner_view: params[:is_owner_view],
                     meta: {count: collection_results.count, counts: task_counts},
                     adapter: :json
      end

      def task_due_dates
        collection = []
        if params[:user_id]
          selected_user_id = params[:user_id]
          collection = TaskUserConnection.find_by_sql ['SELECT "task_user_connections".* FROM "task_user_connections" INNER JOIN (SELECT due_date, MIN(task_user_connections.id) as id FROM task_user_connections INNER JOIN users AS task_owner ON task_owner.id = task_user_connections.owner_id AND task_owner.state <> \'new\' where task_user_connections.user_id = ? GROUP BY due_date) AS connection ON task_user_connections.due_date = connection.due_date AND task_user_connections.id = connection.id  ORDER BY "task_user_connections"."due_date" ASC', selected_user_id]
        elsif params[:owner_id]
          collection = TaskUserConnection.find_by_sql ['SELECT "task_user_connections".* FROM "task_user_connections" INNER JOIN (SELECT due_date, MIN(task_user_connections.id) as id FROM task_user_connections INNER JOIN users AS task_user ON task_user.id = task_user_connections.user_id INNER JOIN tasks ON tasks.id = task_user_connections.task_id AND tasks.task_type <> ? AND task_user.state <> \'new\' AND (task_user.outstanding_tasks_count > 0 OR (task_user.incomplete_paperwork_count + task_user.incomplete_upload_request_count) > 0 OR task_user.start_date > ?) where task_user_connections.owner_id = ? GROUP BY due_date) AS connection ON task_user_connections.due_date = connection.due_date AND task_user_connections.id = connection.id  ORDER BY "task_user_connections"."due_date" ASC', "4", Sapling::Application::ONBOARDING_DAYS_AGO.strftime("%d %b %Y"), params[:owner_id]]
        end
        respond_with collection,
                     each_serializer: TaskUserConnectionSerializer::DueDate,
                     user_id: params[:user_id],
                     owner_id: params[:owner_id]
      end

      def all_completed
        task_count = TaskUserConnection.joins(:task).where(tasks: {task_type: params[:task_type]}, user_id: params[:user_id], owner_id: params[:owner_id], state: 'in_progress' ).count
        render json: { count: task_count }, status: 200
      end

      def buddy_activities_count
        count = get_completed_activities_count(3, 'buddy', params[:user_id], params[:buddy_id], 'in_progress')
        render json: { count: count }, status: 200
      end

      def get_tasks_count
        tasks_count_params = collection_params.merge(count: true)
        params_tasks_count = TaskUserConnectionsCollection.new(tasks_count_params).results
        overdue_tasks_count = TaskUserConnectionsCollection.new(overdue_tasks_params).results
        completed_tasks_count = TaskUserConnectionsCollection.new(completed_tasks_params).results
        pending_tasks_count = TaskUserConnectionsCollection.new(pending_tasks_params).results
        respond_with json: { query_count: params_tasks_count, completed_tasks_count: completed_tasks_count, overdue_tasks_count: overdue_tasks_count, pending_tasks_count: pending_tasks_count}
      end

      def get_tasks_count_against_workflow
        counts = TaskUserConnectionsCollection.new(multiple_tasks_count_params.merge(workspace_task_filter: true, not_pending: true, company_id: current_company.id)).results.to_a.first
        {
          in_complete_count: counts.in_complete_count,
          completed_tasks_count: counts.completed_tasks_count,
          overdue_tasks_count: counts.overdue_tasks_count,
          pending_tasks_count: counts.pending_tasks_count
        }
      end

      def get_active_task_users
        tasks_count_params = collection_params.merge(unique_user_count: true)
        active_users_count = TaskUserConnectionsCollection.new(tasks_count_params).results

        render json: { active_users_count: active_users_count}, status: 200
      end

      def bulk_complete
        tasks = TaskUserConnection.where(task_id: params[:task_id], owner_id: params[:owner_id])
        tasks.update_all(state: "completed", completed_by_method: TaskUserConnection.completed_by_methods[:user], completed_at: Time.now.in_time_zone(current_company&.time_zone), completion_date: Time.now.in_time_zone(current_company&.time_zone).to_date)
        Interactions::Users::FixUserCounters.new(current_company.users.find_by(id: params[:owner_id]), true).perform
        respond_with status: 200
      end

      def get_workspace_tasks_count_against_workflow
        counts = TaskUserConnectionsCollection.new(multiple_workspace_tasks_count_params).results.to_a.first

        {
          completed_tasks_count: counts.completed_tasks_count,
          open_tasks_count: counts.open_task_count,
          overdue_tasks_count: counts.overdue_tasks_count,
          assigned_tasks_count: counts.assigned_tasks_count
        }
      end

      def workspace_paginated
        collection = TaskUserConnectionsCollection.new(workspace_collection_params)
        task_counts = get_workspace_tasks_count_against_workflow
        respond_with collection.results,
                     each_serializer: TaskUserConnectionSerializer::Basic,
                     meta: {count: collection.count, counts: task_counts},
                     adapter: :json
      end

      def get_workspace_tasks_count
        tasks_count_params = workspace_collection_params.merge(count: true)
        params_tasks_count = TaskUserConnectionsCollection.new(tasks_count_params).results
        open_tasks_count = TaskUserConnectionsCollection.new(workspace_open_task_params).results
        overdue_tasks_count = TaskUserConnectionsCollection.new(workspace_overdue_task_params).results
        assigned_tasks_count = TaskUserConnectionsCollection.new(workspace_assigned_task_params).results
        complete_tasks_count = TaskUserConnectionsCollection.new(workspace_complete_task_params).results
        respond_with json: { query_count: params_tasks_count, complete_tasks_count: complete_tasks_count, overdue_tasks_count: overdue_tasks_count, open_tasks_count: open_tasks_count, assigned_tasks_count: assigned_tasks_count}
      end

      def workspace_task_update
        @task_user_connection.update(task_user_connection_params)
        UserMailer.task_reassign_email(@task_user_connection).deliver_later! if params[:is_owner_reassigning] && (@task_user_connection.before_due_date.nil? || @task_user_connection.before_due_date.in_time_zone(@task_user_connection.user.company.time_zone) <= Time.now)
        respond_with @task_user_connection,
          workspace_id: params[:workspace_id],
          company_id: current_company.id,
          serializer: TaskUserConnectionSerializer::UpdateWithWorkspaceCount
      end

      def workspace_show
        respond_with @task_user_connection,
          workspace_id: params[:workspace_id],
          company_id: current_company.id,
          serializer: TaskUserConnectionSerializer::UpdateWithWorkspaceCount
      end

      def soft_delete_workflow
        TaskUserConnectionsCollection.new(collection_params).results.destroy_all
        respond_with status: 200
      end

      def hard_delete_workflow
        TaskUserConnectionsCollection.new(deleted_tasks_params).results
                                      .each do |task|
                                        task.really_destroy!
                                      end

        task_user = current_company.users.find_by_id(params[:user_id])
        if task_user.present?
          task_user.fix_counters
        end

        respond_with status: 200
      end

      def soft_delete_task
        user = current_company.users.find_by_id(params[:employee_id])
        if user
          user.task_user_connections.find_by_id(params[:id]).destroy
          respond_with status: 200
        else
          respond_with status: 500
        end
      end

      def delete_offboarding_tasks
        user = current_company.users.find_by_id(params[:employee_id])
        if user
          user.task_user_connections.where(id: params[:tasks_to_be_deleted]).each { |task_c| task_c.really_destroy! }
          respond_with status: 200
        else
          respond_with status: 500
        end
      end

      def hard_delete_task
        user = current_company.users.find_by_id(params[:user_id])
        if user
          task = user.task_user_connections.with_deleted.find_by_id(params[:id])
          task_user = task.user
          # task.really_destroy!
        end
        task_counts = get_tasks_count_against_workflow
        if task_user.present?
          task_user.fix_counters
        end
        respond_with task_counts.to_json
      end

      def undo_delete_workflow
        TaskUserConnectionsCollection.new(deleted_tasks_params).results
                                      .each do |task|
                                        task.restore(recursive: true)
                                      end
        respond_with status: 200
      end

      def undo_delete_task
        user = current_company.users.find_by_id(params[:employee_id])
        if user
          task = user.task_user_connections.with_deleted.find_by_id(params[:id])
          task.restore(recursive: true)
          respond_with status: 200
        else
          respond_with status: 404
        end
      end

      private

      def assign_params
        params[:tasks] || []
      end

      def tasks_ids
        @tasks_ids ||= assign_params.map { |task| task[:id] }
      end

      def get_completed_activities_count(task_type, outcome_type, user_id, owner_id, state)
        TaskUserConnection.joins(:task).where(tasks: {task_type: task_type}, user_id: user_id, owner_id: owner_id, state: state ).count
      end

      def task_user_connection_params
        params.permit(:id, :owner_id, :state, :due_date, :is_custom_due_date, :from_due_date, :agent_id, :sub_task_state, :owner_type, :send_to_asana, :completed_by_method)
      end

      def multiple_tasks_count_params
        params.permit(:user_id, :owner_id, :workstream_id, :transition, :send_to_asana, :hide_incomplete_user).merge(multiple_task_count: true, company_id: current_company.id)
      end

      def multiple_workspace_tasks_count_params
        params.permit(:user_id, :owner_id, :workstream_id, :transition, :workspace_id, :overdue_in, :send_to_asana).merge(multiple_workspace_task_count: true, company_id: current_company.id)
      end

      def workspace_collection_params
        params.merge(company_id: current_company.id, task_page: 'workspace')
      end

      def collection_params
        not_pending = !params[:pending]
        params.merge(company_id: current_company.id, not_pending: not_pending)
      end

      def overdue_tasks_params
        collection_params.merge(count: true, pending: false, overdue: true, state: 'in_progress', not_pending: true)
      end

      def workspace_overdue_task_params
        workspace_collection_params.merge(count: true, status: 'overdue', state: 'in_progress')
      end

      def workspace_open_task_params
        workspace_collection_params.merge(count: true, status: 'open', state: 'in_progress')
      end

      def workspace_assigned_task_params
        workspace_collection_params.merge(count: true, status: 'assigned', state: 'in_progress')
      end

      def workspace_complete_task_params
        workspace_collection_params.merge(count: true, state: 'completed')
      end

      def pending_tasks_params
        collection_params.merge(count: true, overdue: false, pending: true, state: 'in_progress', not_pending: false)
      end

      def deleted_tasks_params
        collection_params.merge(include_deleted: true)
      end

      def completed_tasks_params
        {
          user_id: params[:user_id],
          owner_id: params[:owner_id],
          state: 'completed',
          count: true,
          pending: false,
          transition: collection_params[:transition],
          company_id: current_company.id
        }
      end

      def log_event(old_state)
        if old_state != @task_user_connection.state
          history_description= nil
          slack_description = nil
          task_name = ActionView::Base.full_sanitizer.sanitize(@task_user_connection.task[:name]) if @task_user_connection.task[:name]
          if @task_user_connection.state == 'completed'
            history_distription = I18n.t('history_notifications.task.completed', name: @task_user_connection.task[:name], assignee_name: @task_user_connection.owner.try(:full_name))
            slack_description = I18n.t('slack_notifications.task.completed', name: task_name, assignee_name: @task_user_connection.owner.try(:full_name))
          elsif @task_user_connection.state == 'in_progress'
            history_distription = I18n.t('history_notifications.task.incompleted', name: @task_user_connection.task[:name], assignee_name: @task_user_connection.owner.try(:full_name))
            slack_description = I18n.t('slack_notifications.task.incompleted', name: task_name, assignee_name: @task_user_connection.owner.try(:full_name))
          end
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: slack_description
          }) if slack_description.present?
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: history_description,
            attached_users: [@task_user_connection.owner.try(:id)]
          }) if history_description.present?
        end
      end

      def task_platform_visibility
        ::PermissionService.new.checkTaskPlatformVisibility(current_user, (params[:owner_id] || params[:user_id]))
      end

      def is_assign_date_in_past?(user)
        (user.present? && @task_user_connection.before_due_date.in_time_zone(user.company.time_zone) <= Time.now)
      end

    end
  end
end
