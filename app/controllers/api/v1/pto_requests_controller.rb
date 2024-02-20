module Api
  module V1
    class PtoRequestsController < ApiController
      include AttachmentSharedMethods
      before_action :require_company!
      before_action :authenticate_user!

      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end

      load_and_authorize_resource
      before_action :set_user, except: [:get_users_out_of_office]
      before_action :set_pto , only: [:show, :update, :destroy, :approve_or_deny, :hours_used]
      before_action :check_platform_visibility, except: [:get_users_out_of_office]
      before_action :can_create, only: [:create, :cancel_request, :hours_used, :destory]
      before_action :authorize_attachments, only: [:create, :update]
      # before_action :check_if_approved, only: [:update]
      def create
        service_response = PtoRequestService::RestOps::CreateRequest.new(pto_request_params, current_user.id).perform
        if service_response.errors.empty?
          respond_with service_response, serializer: PtoRequestSerializer::Basic, scope: {get_balances: true}
        else
          render json: {errors: [{messages: service_response.errors.full_messages.uniq, status: "422", remaining_balance: service_response.assigned_pto_policy.total_balance}]}, status: 422
        end
      end

      def show
        render json: @pto_request, serializer: PtoRequestSerializer::ShowRequest
      end

      def hours_used
        @pto_request.attributes = pto_request_params.except('attachment_ids') if @pto_request.present?
        pto_request = @pto_request.present? ? @pto_request : @user.pto_requests.new(pto_request_params)
        pto_request.balance_hours = pto_request.get_balance_used
        render json: {hours_used: pto_request.balance_hours, available_balance: available_balance(pto_request)}, status: 200
      end

      def update
        service_response = PtoRequestService::RestOps::UpdateRequest.new(pto_request_params, @pto_request, current_user.id).perform
        if service_response.errors.empty?
          respond_with service_response, serializer: PtoRequestSerializer::Basic, scope: {get_balances: true}
        else
          render json: {errors: [{messages: service_response.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def approve_or_deny
        pto_request = PtoRequestService::CrudOperations.new.approve_or_deny(@pto_request, params[:status], current_user, false, "#{current_user.id}") if params[:status]
        if pto_request.errors.empty?
          respond_with pto_request, serializer: PtoRequestSerializer::Basic, scope: {get_balances: true}
        else
          render json: {errors: [{messages: pto_request.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def cancel_request
        pto_request = PtoRequestService::CrudOperations.new(pto_request_params, @user, current_user).cancel_pto("#{current_user.id}")
        if pto_request.errors.empty?
          respond_with pto_request, serializer: PtoRequestSerializer::Basic, scope: {get_balances: true}
        else
          render json: {errors: [{messages: pto_request.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def historical_requests
        respond_with @user.pto_requests.individual_requests.includes(:pto_policy).historic_requests(current_company.time.to_date)
            .where('extract(year from begin_date) = ? OR extract(year from end_date) = ?', current_company.time.year, current_company.time.year), each_serializer: PtoRequestSerializer::Basic
      end

      def upcoming_requests
        respond_with @user.pto_requests.individual_requests.includes(:pto_policy).upcoming_requests(current_company.time.to_date), each_serializer: PtoRequestSerializer::Basic
      end

      def get_users_out_of_office
        collection = PtoRequestsCollection.new(collection_params)
        if params[:updates_page]
          respond_with collection.results, each_serializer: PtoRequestSerializer::OutOfOfficeUpdates, meta: {count: collection.count}, adapter: :json
        else
          respond_with collection.results, each_serializer: PtoRequestSerializer::OutOfOffice, meta: {count: collection.count}, adapter: :json
        end
      end

      def destroy
        @pto_request.destroy
        if @pto_request.errors.empty?
          head 204
        else
          render json: {errors: [{messages: @pto_request.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      private

      def collection_params
        params.merge(company_id: current_company.id)
      end

      def pto_request_params
        params.permit(:id, :partial_day_included, :pto_policy_id, :begin_date, :end_date, :additional_notes, :status, :approval_denial_date, :balance_hours, :permission_bypass, :auto_complete, :user_id, comments_attributes: [:description, :commenter_id, company_id: current_company.id, :mentioned_users => []])
        .merge(attachment_ids: attachment_ids)
      end

      def set_pto
        @pto_request = @user.pto_requests.includes(:pto_policy).find_by(id: params[:id])
      end

      def set_user
        @user = current_company.users.find_by(id: params[:user_id])
        respond_with status: 404 if @user.blank?
      end

      def check_platform_visibility
        return  if @user.present? && current_user.id == @user.manager_id && pto_request_params[:permission_bypass]
        ::PermissionService.new.checkTimeOffPlatformVisibility(current_user, params[:user_id])
      end

      def can_create
        return  if current_user.id == @user.manager_id && pto_request_params[:permission_bypass]
        raise CanCan::AccessDenied if current_user.id.try(:to_s) != params[:user_id].try(:to_s) && current_user.user_role.is_time_off_visibility_valid? && current_user.user_role.permissions["platform_visibility"]["time_off"] != 'view_and_edit'
      end

      def check_if_approved
        if @pto_request.status == "approved"
          @pto_request.errors.add(:base, I18n.t('errors.update_error'))
          render json: {errors: [{messages: @pto_request.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      def available_balance pto_request
        pto_request.pto_policy.unlimited_policy ? nil : pto_request.remaining_balance
      end
    end
  end

end
