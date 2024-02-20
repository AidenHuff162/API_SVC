module Api
  module V1
    class ActivitiesController < ApiController
      before_action :require_company!
      before_action :authenticate_user!

      before_action :context, except: [:ctus_activities]

      def create
        if @context.present?
          @activity = @context.activities.new(activity_param)
          @activity.save!
          respond_with @activity, serializer: ActivitySerializer::Full, company: current_company
        else
          head 404
        end
      end

      def index
        respond_with @context.activities.with_deleted.includes(:agent).order('created_at DESC'), each_serializer: ActivitySerializer::Full, company: current_company
      end

      def pending_ctus_activities
        respond_with @context.activities, each_serializer: ActivitySerializer::Full, company: current_company
      end

      def ctus_activities
        if params[:user_id].present?
          accessible_table_ids = PermissionService.new.fetch_accessable_custom_tables(current_company, current_user, params[:user_id]).map(&:to_i)
          ctus_activities = Activity.with_deleted.joins("INNER JOIN custom_table_user_snapshots on activities.activity_id = custom_table_user_snapshots.id AND activities.activity_type = 'CustomTableUserSnapshot'")
            .where("custom_table_user_snapshots.user_id = ? AND custom_table_user_snapshots.custom_table_id IN (?) AND (custom_table_user_snapshots.deleted_at is NULL OR custom_table_user_snapshots.deleted_at is NOT NULL)", params[:user_id], accessible_table_ids)
          paginated_activities = ctus_activities.paginate(page: params[:page], per_page: 3).order('created_at DESC') if ctus_activities.present?
          respond_with paginated_activities, each_serializer: ActivitySerializer::ForUpdatesCtus, company: current_company, total_entries: paginated_activities.total_entries if paginated_activities.present?
        end
      end

      private
      def activity_param
        params.permit(:agent_id, :description)
      end

      def context
        @context = nil
        if params[:task_user_connection_id]
          @context = TaskUserConnection.with_deleted.find_by(id: params[:task_user_connection_id])
        elsif params[:custom_table_user_snapshot_id]
          @context = CustomTableUserSnapshot.unscoped.find_by(id: params[:custom_table_user_snapshot_id])
        end
      end
    end
  end
end
