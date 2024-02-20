module Api
  module V1
    module Admin
      class TasksController < BaseController
        include AttachmentSharedMethods
        load_and_authorize_resource :workstream, except: :update_workstream
        load_and_authorize_resource :task, through: :workstream, shallow: true
        before_action :authorize_attachments, only: [:create, :update]

        def create
          @task.save!
          respond_with @task, serializer: TaskSerializer::Base

          task_name = ActionView::Base.full_sanitizer.sanitize(@task[:name]) if @task[:name]
          PushEventJob.perform_later('task-created', current_user, {
            task_name: @task[:name],
            task_type: @task.task_type
          })
          history_task_type = @task.task_type == 'hire' ? 'New Hire' : @task.task_type
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.task.created", name: task_name, type: history_task_type)
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t("history_notifications.task.created", name: @task[:name], type: history_task_type)
          })
        end

        def show
          respond_with @task, serializer: TaskSerializer::Base
        end

        def index
          respond_with @tasks.includes(:attachments, :sub_tasks, :workspace, owner: [:profile_image]), each_serializer: TaskSerializer::Base
        end

        def update
          @task.update!(task_params)
          respond_with @task, serializer: TaskSerializer::Base

          task_name = ActionView::Base.full_sanitizer.sanitize(@task[:name]) if @task[:name]
          PushEventJob.perform_later('task-updated', current_user, {
            task_name: @task[:name],
            task_type: @task.task_type
          })
          history_task_type = @task.task_type == 'hire' ? 'New Hire' : @task.task_type
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.task.updated", name: task_name, type: history_task_type)
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t("history_notifications.task.updated", name: @task[:name], type: history_task_type)
          })
        end

        def paginated
          collection = TasksCollection.new(collection_params)
          meta = {
            tasks_data: collection.meta_without_duplicate_keys,
            total_open_tasks: collection.total_open_tasks,
            total_overdue_tasks: collection.total_overdue_tasks
          }
          respond_with collection.results,
                       each_serializer: TaskSerializer::Dashboard,
                       meta: meta,
                       adapter: :json
        end

        def workflow_task_paginated
          collection = TasksCollection.new(paginated_params)
          results = collection.results.includes(:attachments, :sub_tasks, :workspace, owner: [:profile_image])

          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : results.count,
            recordsFiltered: collection.nil? ? 0 : results.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: TaskSerializer::Base)
          }
        end

        def update_workstream
          workstream = current_company.workstreams.find_by(id: params[:source_workstream_id])
          task = workstream.tasks.find_by(id: params[:id]) rescue nil
          if task
            task.update!(update_workstream_params)
            respond_with task, serializer: TaskSerializer::Base
          else
            respond_with status: 404
          end

        end

        def duplicate_task
          current_task = @task
          current_workstream = current_company.workstreams.find_by(id: current_task.workstream_id)
          tasks = current_workstream.tasks.where("position > ?", current_task.position)
          tasks.update_all("position= position + 1") if tasks.present?
          new_task = current_task.dup
          new_task.position = current_task.position + 1
          index = current_task.name[0..2] == '<p>' ? 3 : 0
          new_task.name = current_task.name.insert(index, 'Copy of ')
          current_task.attachments.each do |attachment|
            file = upload_attachment(attachment)
            new_task.attachments.push file if file.present?
          end
          current_task.sub_tasks.each { |sub_task| new_task.sub_tasks.push sub_task.dup }
          new_task.save!

          respond_with new_task, serializer: TaskSerializer::Basic
          PushEventJob.perform_later('task-created', current_user, {
            task_name: new_task[:name],
            task_type: new_task.task_type
          })
          history_task_type = new_task.task_type == 'hire' ? 'New Hire' : new_task.task_type
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.task.created", name: new_task[:name], type: history_task_type)
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t("history_notifications.task.created", name: new_task[:name], type: history_task_type)
          })
        end

        def destroy
          task_name = ActionView::Base.full_sanitizer.sanitize(@task[:name]) if @task[:name]
          PushEventJob.perform_later('task-deleted', current_user, {
            task_name: @task[:name],
            task_type: @task.task_type
          })
          history_task_type = @task.task_type == 'hire' ? 'New Hire' : @task.task_type
          SlackNotificationJob.perform_later(current_company.id, {
            username: current_user.full_name,
            text: I18n.t("slack_notifications.task.deleted", name: task_name, type: history_task_type)
          })
          History.create_history({
            company: current_company,
            user_id: current_user.id,
            description: I18n.t("history_notifications.task.deleted", name: @task[:name], type: history_task_type)
          })
          @task.deleted_at = 0.seconds.ago
          @task.save(validate: false)
          Workstream.reset_counters(@task.workstream_id, :tasks)
          DestroyTaskJob.perform_later(@task.id)
          render body: Sapling::Application::EMPTY_BODY, status: 204
        end

        private
        def collection_params
          params.merge(company_id: current_company.id)
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          params.merge(company_id: current_company.id, page: page, per_page: params[:length])
        end

        def task_params
          params.merge!(sub_tasks_attributes: (params[:sub_tasks] || [{}]))
                .permit(:name, :description, :deadline_in, :owner_id, :position, :task_type, :updated_from_admin_tasks,
                        :is_retroactive, :time_line, :before_deadline_in, :agent_id, :workspace_id, :custom_field_id,
                        :survey_id, :dependent_tasks => [], sub_tasks_attributes: %i[id title state position _destroy],
                                                      task_schedule_options: %i[due_date_timeline assign_on_timeline
                                                                                due_date_relative_key
                                                                                assign_on_relative_key
                                                                                due_date_custom_date
                                                                                assign_on_custom_date])
                .merge(attachment_ids: attachment_ids)
        end

        def update_workstream_params
          params.permit(:workstream_id)
        end
      end
    end
  end
end
