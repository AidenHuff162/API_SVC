module Api
  module V1
    class WorkspacesController < BaseController
      load_and_authorize_resource

      def show
        respond_with @workspace, serializer: WorkspaceSerializer::Short, user_id: current_user.id
      end

      def basic
        respond_with @workspace, serializer: WorkspaceSerializer::Basic, user_id: current_user.id
      end

      def update
        @workspace.update!(workspace_params)
        respond_with @workspace, serializer: WorkspaceSerializer::Short, user_id: current_user.id
      end

      def destroy
        @workspace.task_user_connections
          .where(owner_type: TaskUserConnection.owner_types[:workspace])
          .update_all(owner_type: TaskUserConnection.owner_types[:individual], owner_id: @workspace.created_by)
        @workspace.tasks.update_all(task_type: Task.task_types[:owner], owner_id: @workspace.created_by)

        @task_user_connection = @workspace.task_user_connections.where(owner_type: TaskUserConnection.owner_types[:individual])
        @task_user_connection.each do |con|
          UserMailer.task_reassign_email(con).deliver_later! if (con.before_due_date.nil? || con.before_due_date.in_time_zone(con.user.company.time_zone) <= Time.now)
        end
        @workspace.destroy!
        head 204
      end

      private

      def workspace_params
        params.permit(:id, :name, :workspace_image_id, :time_zone, :associated_email, :notification_all, notification_ids:[]).merge(company_id: current_company.id)
      end
    end
  end
end
