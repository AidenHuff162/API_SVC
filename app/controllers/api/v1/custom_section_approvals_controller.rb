module Api
  module V1
    class CustomSectionApprovalsController < BaseController
      before_action :authenticate_user!
      before_action :authorize_user, only: [:updates_page_cs_approvals, :get_custom_section_approval_values, :update, :destroy]
      load_resource only: [:destroy, :update, :dashboard_cs_approval_requests, :dispatch_request_change_email]
      authorize_resource only: [:destroy_requested_fields]

      before_action only: [:get_custom_section_approval_values] do
        ::CustomSectionApprovalPermissionService.new.can_view_approval_values(current_user, params[:cs_approval_id], current_company, params[:user_id])
      end

      before_action only: [:update] do
        ::CustomSectionApprovalPermissionService.new.can_update_approval(current_user, params[:id], current_company)
      end

      before_action only: [:destroy] do
        ::CustomSectionApprovalPermissionService.new.can_update_approval(current_user, params[:id], current_company, true)
      end

      before_action only: [:destroy_requested_fields] do
        ::PermissionService.new.checkAdminVisibility(current_user, 'records')
      end
      
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 403
      end

      def get_custom_section_approval_values
        values = CustomSectionApproval.get_custom_section_approval_values(params[:user_id], params[:cs_approval_id], current_company)
        render json: { values: values }, status: 200
      end

      def destroy_requested_fields
        CustomSectionApproval.destroy_requested_fields(params[:field_id], params[:is_default], params[:section_id], current_company)
        head 204
      end

      def destroy
        @custom_section_approval.destroy!
        head 204
      end

      def update
        @custom_section_approval.update!(custom_section_approval_params)
        CustomSections::AssignRequestedFieldValue.new.assign_values_to_user(@custom_section_approval) if @custom_section_approval.reload.approved?
        respond_with @custom_section_approval, serializer: CustomSectionApprovalSerializer::Basic
      end

      def updates_page_cs_approvals
        collection = CustomSectionApprovalsCollection.new(updates_page_cs_approval_params)
        respond_with collection.results, each_serializer: CustomSectionApprovalSerializer::ForUpdates
      end

      def paginated_dashboard_cs_approval_requests
        collection = CustomSectionApprovalsDashboardCollection.new(dashboard_cs_params)
        results = collection.results

        meta = {
          draw: params[:draw].to_i,
          recordsTotal: collection.nil? ? 0 : collection.count,
          recordsFiltered: collection.nil? ? 0 : collection.count
        }

        render json: {
          data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: CustomSectionApprovalSerializer::ForDashboard,company: current_company),
          meta: meta
        }
      end

      def dashboard_cs_approval_requests
        if @custom_section_approval
          respond_with @custom_section_approval, serializer: CustomSectionApprovalSerializer::ForDashboardView, company: current_company, user: current_user
        else
          head :ok
        end
      end

      def dispatch_request_change_email
        @custom_section_approval.dispatch_request_change_email
        head :ok
      end

      def email_dashboard_approved_requests
        WriteApprovedCsaCSVJob.perform_async(current_company.id, current_user.id, true)
      end

      def create_profile_approval_with_requested_fields
        CustomSections::CustomSectionApprovalManagement.new(current_company, params[:user_id]).trigger_profile_approval_request(current_user.id, params[:custom_section_id], params[:changed_fields].to_h, params[:updated_approval_chains].to_h)
      end

      private

      def updates_page_cs_approval_params
        current_user_id = params[:id].present? ? params[:id] : current_user.id
        current_user_role = current_company.users.find_by(id: current_user_id).try(:user_role_id)
        params.merge!(isSuperAdmin: true) if current_user_id.try(:to_i) == current_user.id && current_user.account_owner?
        params.merge!(company_id: current_company.id, updates_page: true, current_user_id: current_user_id, current_user_role: current_user_role)
      end

      def custom_section_approval_params
        params.merge!(cs_approval_chains_attributes: (params[:current_approval_chain] || [{}]))
          .permit(:id, :custom_section_id, :user_id, :requester_id, :state, cs_approval_chains_attributes: [:id, :state, :approver_id, :approval_date])
      end

      def dashboard_cs_params
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
