module Api
  module V1
    class TasksController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      def index
        collection = TasksCollection.new(collection_params)
        respond_with collection.results, each_serializer: TaskSerializer::WithConnections, user_id: params[:user_id], owner_id: params[:owner_id]
      end

      def basic_index
        collection = TasksCollection.new(collection_params)

        if params[:exclude_by_user_id].nil?
          user_id = params[:exclude_by_owner_id]
        else
          user_id = params[:exclude_by_user_id]
        end
        respond_with collection.results, each_serializer: TaskSerializer::Basic, user_id: user_id
      end

      def update
        save_respond_with_form

        task_name = ActionView::Base.full_sanitizer.sanitize(task_params[:name]) if task_params[:name]
        PushEventJob.perform_later('task-update', current_user, {
          workstream_name: task_params[:workstream][:name],
          task_name: task_params[:name],
          task_type: task_params[:task_type],
          task_state: task_params[:task_user_connections].first[:state]
        })
        history_task_type = task_params[:task_type] == 'hire' ? 'New Hire' : task_params[:task_type]
        SlackNotificationJob.perform_later(current_company.id, {
          username: current_user.full_name,
          text: I18n.t(task_name, type: history_task_type)
        })
        History.create_history({
          company: current_company,
          user_id: current_user.id,
          description: I18n.t("history_notifications.task.updated", name: task_params[:name], type: history_task_type)
        })
      end

      private
      def save_respond_with_form
        form = TaskForm.new(task_params)
        form.save!
        respond_with form.task, serializer: TaskSerializer::WithConnections
      end

      def task_params
        params.merge({company_id: current_company.id})
      end

      def collection_params
        params.merge(company_id: current_company.id)
      end
    end
  end
end
