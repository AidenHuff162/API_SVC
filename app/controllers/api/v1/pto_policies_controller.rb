module Api
  module V1
    class PtoPoliciesController < ApiController
      before_action :authenticate_user!
      before_action :require_company!

      def filter_policies
        filtered_data = Pto::FilterPtoDataByTypeOrYear.new(filtering_params[:type], filtering_params[:year], filtering_params[:user_id], filtering_params[:reset], filtering_params[:operation_type]).perform
        respond_with filtered_data
      end

      def policy_eoy_balance
        policy = current_company.pto_policies.find_by(id: params[:id])
        eoy_balance = policy.eoy_balance(params[:user_id]) if params[:user_id] && policy.present?
        render json: {eoy_balance: eoy_balance}, status: 200
      end

      private

      def filtering_params
        params.permit(:type, :year, :user_id, :reset, :operation_type)
      end

    end
  end
end
