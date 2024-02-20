module Api
  module V1
    class AssignedPtoPoliciesController < ApiController
      before_action :authenticate_user!
      before_action :set_assigned_policy,  only:[:estimated_balance]

      def estimated_balance
        resp = Pto::PtoEstimateBalance.new(@assigned_pto_policy, params[:estimate_date], current_company).perform
        respond_with resp, serializer: EstimatedBalanceSerializer
      end

      private
      def employee
        current_company.users.includes(:assigned_pto_policies).find(params[:employee_id])
      end
      def set_assigned_policy
        @assigned_pto_policy = employee.assigned_pto_policies.includes(:pto_policy).find_by(pto_policy_id: params[:pto_policy_id])
      end
    end
  end
end
