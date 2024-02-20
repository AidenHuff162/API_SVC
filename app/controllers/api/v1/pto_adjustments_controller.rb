module Api
  module V1
    class PtoAdjustmentsController < ApiController
      before_action :require_company!
      before_action :authenticate_user!
      before_action :set_user
      before_action :set_employee
      before_action :set_assigned_pto_policy , only: [:create]
      before_action :set_adjustment , only: [:destroy]
      before_action only: [:create] do
        ::PermissionService.new.checkPlatformVisibilityPtoAdjustment(current_user, @employee)
      end
      rescue_from CanCan::AccessDenied do |exception|
        render body: Sapling::Application::EMPTY_BODY, status: 204
      end
      load_and_authorize_resource
      def create
        pto_adjustment = PtoAdjustment.new(pto_adjustment_params)
        if pto_adjustment.save
          pto_adjustment.reload
          respond_with pto_adjustment, serializer: PtoAdjustmentSerializer::Basic
        else
          render json: {errors: [{messages: pto_adjustment.errors.full_messages, status: "422"}]}, status: 422
        end

      end

      def index
        pto_adjustments = PtoAdjustment.joins(:assigned_pto_policy).where("assigned_pto_policies.user_id = ? and (extract(year from effective_date) = ?) and is_applied = ?", params[:user_id], current_company.time.year, true).uniq
        respond_with pto_adjustments, each_serializer: PtoAdjustmentSerializer::Basic
      end

      def destroy
        @pto_adjustment.deleted_by_user = true
        @pto_adjustment.destroy
        if @pto_adjustment.errors.empty?
          head 200
        else
          render json: {errors: [{messages: @pto_adjustment.errors.full_messages, status: "422"}]}, status: 422
        end
      end

      private
      def pto_adjustment_params
        params.permit(:id, :hours, :description, :effective_date, :operation, :creator_id, :assigned_pto_policy_id)
      end

      def set_assigned_pto_policy
        params[:creator_id] = current_user.id
        @assigned_pto_policy = @employee.assigned_pto_policies.where(pto_policy_id: params[:pto_policy_id]).first
        params.merge!(assigned_pto_policy_id: @assigned_pto_policy.id)
      end

      def set_adjustment
        pto_policy = @employee.assigned_pto_policies.find_by(pto_policy_id: params[:pto_policy_id]) rescue nil
        if pto_policy
         @pto_adjustments = pto_policy.pto_adjustments.find_by(id: params[:id])
        end
      end

      def set_user
        @user = current_company.users.find_by(id: params[:user_id])
      end

      def set_employee
        @employee = params[:user_id] == params[:employee_id] ? @user : current_company.users.find_by(id: params[:employee_id])
      end
    end
  end

end
