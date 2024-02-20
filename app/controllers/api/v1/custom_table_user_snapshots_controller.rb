module Api
  module V1
    class CustomTableUserSnapshotsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!
      load_and_authorize_resource except: [:updates_page_ctus,:email_dashboard_approved_requests, :paginated_dashboard_approval_requests, :dashboard_approval_requests, :dispatch_request_change_email]
      load_resource only: [:dashboard_approval_requests, :dispatch_request_change_email]

      before_action only: [:update] do 
        ::PermissionService.new.can_not_approve_invalid_manager(current_user, params[:id]) if CtusApprovalChain.current_approval_chain(params[:id])&.first&.approval_chain&.approval_type == "manager" && current_user.user_role.role_type != "super_admin"
        ::PermissionService.new.can_not_approve_invalid_person(current_user, params[:id]) if CtusApprovalChain.current_approval_chain(params[:id])&.first&.approval_chain&.approval_type == "person" && current_user.user_role.role_type != "super_admin"
        ::PermissionService.new.can_not_approve_invalid_permission(current_user, current_company, params[:id]) if CtusApprovalChain.current_approval_chain(params[:id])&.first&.approval_chain&.approval_type == "permission" && current_user.user_role.role_type != "super_admin"
        ::PermissionService.new.can_not_approve_invalid_coworker(current_user, params[:id]) if CtusApprovalChain.current_approval_chain(params[:id])&.first&.approval_chain&.approval_type == "coworker" && current_user.user_role.role_type != "super_admin"
      end

      before_action only: [:destroy] do
        ::PermissionService.new.can_not_delete_request_snapshot(params[:id]) if current_user.user_role.role_type != "super_admin"
      end 

     rescue_from CanCan::AccessDenied do |exception|          
        render body: Sapling::Application::EMPTY_BODY, status: 403
      end

      def show
        serializer = @custom_table_user_snapshot.custom_table.is_approval_required ? CustomTableUserSnapshotSerializer::ForInfo : CustomTableUserSnapshotSerializer::ForCreateUpdate
        respond_with @custom_table_user_snapshot, serializer: serializer, company: current_company
      end
      
      def create
        @custom_table_user_snapshot.save!
        @custom_table_user_snapshot.reload
        serializer = @custom_table_user_snapshot.custom_table.is_approval_required ? CustomTableUserSnapshotSerializer::ForInfo : CustomTableUserSnapshotSerializer::ForCreateUpdate
        respond_with @custom_table_user_snapshot, serializer: serializer, company: current_company
      end

      def update
        @custom_table_user_snapshot.update!(custom_table_user_snapshot_params)
        @custom_table_user_snapshot.reload
        serializer = @custom_table_user_snapshot.custom_table.is_approval_required ? CustomTableUserSnapshotSerializer::ForInfo : CustomTableUserSnapshotSerializer::ForCreateUpdate
        respond_with @custom_table_user_snapshot, serializer: serializer, company: current_company
      end

      def updates_page_ctus
        collection = CustomTableUserSnapshotsCollection.new(updates_page_ctus_params)
        respond_with collection.results, each_serializer: CustomTableUserSnapshotSerializer::ForUpdates
      end

      def destroy
        @custom_table_user_snapshot.is_destroyed = params[:is_destroyed] if params[:is_destroyed]
        @custom_table_user_snapshot.terminate_callback = params[:terminate_callback] if params[:terminate_callback]
        @custom_table_user_snapshot.destroy!
        head 204
      end

      def mass_create
        response = CustomTables::PowerUpdate.new(mass_create_params, current_user, current_company).perform
        respond_with status: response
      end

      def user_approval_snapshot_min_date
        response = CustomTables::GetApprovalSnapshotEffectiveDates.new(approval_min_date_params, current_company).perform
        respond_with response
      end

      def dashboard_approval_requests
        if @custom_table_user_snapshot
          respond_with @custom_table_user_snapshot, serializer: CustomTableUserSnapshotSerializer::ForDashboardView, company: current_company, user: current_user
        else
          head :ok
        end
      end

      def dispatch_request_change_email
        @custom_table_user_snapshot.dispatch_email_to_approver
        head :ok
      end

      def paginated_dashboard_approval_requests
        collection = CustomTableUserSnapshotsDashboardCollection.new(dashboard_ctus_params)
        results = collection.results

        meta = {
          draw: params[:draw].to_i,
          recordsTotal: collection.nil? ? 0 : collection.count,
          recordsFiltered: collection.nil? ? 0 : collection.count
        }
          
        render json: {
          data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: CustomTableUserSnapshotSerializer::ForDashboard,company: current_company),
          meta: meta
        }
      end

      def email_dashboard_approved_requests
        file = WriteApprovedCtusCSVJob.perform_async(current_user.id, true)
      end

      private

      def approval_min_date_params
        params.permit(:user_array)
      end

      def mass_create_params
        mass_creation_params = []
        params[:snapshots].each_with_index do |param, index|
          mass_creation_params << param.merge!(custom_snapshots_attributes: (param["custom_snapshots"] || [{}]), edited_by_id: current_user.id)
          .permit(:custom_table_id, :user_id, :state, :edited_by_id, :effective_date, :requester_id, :request_state,  custom_snapshots_attributes: [:id, :custom_field_id, :preference_field_id, :custom_field_value]).to_h
        end
        mass_creation_params
      end

      def custom_table_user_snapshot_params
        params.merge!(custom_snapshots_attributes: (params[:custom_snapshots] || [{}]), edited_by_id: current_user.id, manager_terminate_callback: true, ctus_approval_chains_attributes: params[:current_approval_chain], approval_chains_attributes: params[:approval_chains])
          .permit(:id, :custom_table_id, :user_id, :terminate_callback, :edited_by_id, :effective_date, :state, :requester_id, :request_state, custom_snapshots_attributes: [:id, :custom_field_id, :preference_field_id, :custom_field_value], terminated_data: [:eligible_for_rehire, :last_day_worked, :termination_type], ctus_approval_chains_attributes: [:id, :request_state, :approval_date], approval_chains_attributes: [:approval_type, approval_ids: []])
      end

      def updates_page_ctus_params
        current_user_id = params[:id].present? ? params[:id] : current_user.id
        current_user_role = current_company.users.find_by(id: current_user_id).try(:user_role_id)
        params.merge!(isSuperAdmin: true) if current_user_id.try(:to_i) == current_user.id && current_user.account_owner?
        params.merge!(company_id: current_company.id, updates_page: true, current_user_id: current_user_id, current_user_role: current_user_role)
      end

      def dashboard_ctus_params
        page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
        params.merge(company_id: current_company.id,
                     sort_order: params[:sort_order],
                     sort_column: params[:sort_column],
                     term: params[:term], page: page,
                     per_page: params[:length])
      end
    end
  end
end
