module Api
  module V1
    module Admin
      class PtoPoliciesController < BaseController
        before_action :authenticate_user!
        before_action only: [:index, :show, :timeoff_pto_policy] do
          params['sub_tab'] = params['sub_tab'].present? ? params['sub_tab'] : 'time_off'
          ::PermissionService.new.checkAdminVisibility(current_user, params['sub_tab'])
        end

        before_action only: [:create, :update, :destroy, :enable_disable_policy] do
          params['sub_tab'] = params['sub_tab'].present? ? params['sub_tab'] : 'time_off'
          ::PermissionService.new.checkAdminCanViewAndEditVisibility(current_user, params['sub_tab'])
        end

        load_and_authorize_resource

        def index
          collection = PtoPoliciesCollection.new(collection_params)
          results = collection.results
          if params[:flatfile]
            respond_with results, each_serializer: PtoPolicySerializer::MinimalData
          else
            respond_with results, each_serializer: PtoPolicySerializer::Index
          end
        end

        def timeoff_pto_policy
          collection = PtoPoliciesCollection.new(collection_params)
          results = collection.results
          respond_with results, each_serializer: PtoPolicySerializer::TimeoffData
        end

        def duplicate_pto_policy
          new_policy = Pto::DuplicatePtoPolicy.new(params[:id], current_company).perform

          if new_policy.errors.empty?
            new_policy.reload
            respond_with new_policy, serializer: PtoPolicySerializer::Index
          else
            render json: {errors: [{messages: new_policy.errors.full_messages, status: "422"}]}, status: 422
          end
        end

        def pto_policy_paginated
          collection = PtoPoliciesCollection.new(paginated_params)
          results = collection.results
          render json: {
            draw: params[:draw].to_i,
            recordsTotal: collection.nil? ? 0 : collection.count,
            recordsFiltered: collection.nil? ? 0 : collection.count,
            data: ActiveModelSerializers::SerializableResource.new(results, each_serializer: PtoPolicySerializer::Index)
          }
        end

        def enabled_policies
          collection = PtoPoliciesCollection.new(pto_policy_params.merge(company_id: current_company.id, enabled: true, current_user_id: params[:user_id]))
          results = collection.results
          respond_with results, each_serializer: PtoPolicySerializer::MinimalData
        end

        def create
          pto_policy = Pto::PtoPolicyBusinessLogic.new(pto_policy_params.merge(updated_by_id: current_user.id), current_company).create_pto_policy
          
          if pto_policy.errors.empty?
            pto_policy.reload
            respond_with pto_policy, serializer: PtoPolicySerializer::Index
          else
            render json: {errors: [{messages: pto_policy.errors.full_messages, status: "422"}]}, status: 422
          end
        end

        def update
          pto_policy = Pto::PtoPolicyBusinessLogic.new(pto_policy_params.merge(updated_by_id: current_user.id), current_company).update_pto_policy
          if pto_policy.nil?
            head 500
          elsif pto_policy.errors.empty?
            respond_with pto_policy, serializer: PtoPolicySerializer::Index
          else
            render json: {errors: [{messages: pto_policy.errors.full_messages, status: "422"}]}, status: 422
          end
        end

        def destroy
          policy_removed = Pto::DestroyPolicy::DestroyPtoPolicy.new(pto_policy_params[:id]).perform
          if policy_removed
            history_text = I18n.t("history_notifications.pto_policy.deleted", full_name: current_user.full_name, policy_name: @pto_policy.name).html_safe
            History.create_history({
              company: current_company,
              user_id: current_user.id,
              description: history_text
            })
            head 204
          else
            head 500
          end
        end

        def enable_disable_policy
          pto_policy = Pto::PtoPolicyBusinessLogic.new(pto_policy_params, current_company).enable_disable_policy
          if pto_policy.errors.empty?
            respond_with pto_policy, serializer: PtoPolicySerializer::Index
          else
            render json: {errors: [{messages: pto_policy.errors.full_messages, status: "422"}]}, status: 422
          end
        end

        def upload_balance
          Interactions::Pto::UploadBalance.new(params.to_h, current_company).perform
          render json: {inside_csv_job: true }
        end

        def show
          respond_with @pto_policy, serializer: PtoPolicySerializer::Wizard
        end

        private
        def collection_params
          if params[:meta].present?
            meta = JSON.parse(params[:meta])
            pto_policy_params.merge(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], location_id: meta['location_id'],
             team_id: meta['team_id'], policy_type_id: meta['policy_type_id'], employment_status: meta['employment_status'], term: params[:term])
          else
            pto_policy_params.merge(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], term: params[:term], limited_policies: params[:limited_policies], enabled: params[:enabled], unlimited_policies: params[:unlimited_policies])
          end
        end

        def paginated_params
          page = (params[:start].to_i / params[:length].to_i) + 1 rescue 1
          if params[:meta].present?
            meta = JSON.parse(params[:meta])
            pto_policy_params.merge(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], location_id: meta['location_id'],
             team_id: meta['team_id'], policy_type_id: meta['policy_type_id'], employment_status: meta['employment_status'], term: params[:term], page: page, per_page: params[:length])
          else
            pto_policy_params.merge(company_id: current_company.id, sort_order: params[:sort_order], sort_column: params[:sort_column], term: params[:term], page: page, per_page: params[:length])
          end
        end

        def pto_policy_params
          params["policy_tenureships_attributes"] = params["policy_tenureships"]
          params.merge!(approval_chains_attributes: params[:approval_chains]).permit(:has_stop_accrual_date, :stop_accrual_date, :id, :name, :icon, :for_all_employees, :assign_manually, :policy_type, :is_enabled, :unlimited_policy, :unlimited_type_title,
            :accrual_rate_amount, :accrual_rate_unit, :rate_acquisition_period, :accrual_frequency, :has_max_accrual_amount, :max_accrual_amount,
            :allocate_accruals_at, :start_of_accrual_period, :accrual_period_start_date, :accrual_renewal_time, :accrual_renewal_date, :first_accrual_method,
            :carry_over_unused_timeoff, :has_maximum_carry_over_amount, :maximum_carry_over_amount, :can_obtain_negative_balance, :carry_over_negative_balance,
            :manager_approval, :auto_approval, :tracking_unit, :expire_unused_carryover_balance, :carryover_amount_expiry_date, :working_hours, :half_day_enabled, :days_to_wait_until_auto_actionable,
            :has_maximum_increment, :has_minimum_increment, :minimum_increment_amount, :maximum_increment_amount, :maximum_negative_amount, :display_detail, :is_paid_leave, :show_balance_on_pay_slip,
            working_days: [],
            policy_tenureships_attributes: [:id, :year, :amount, :_destroy], approval_chains_attributes: [:id, :approval_ids, :approval_type, :_destroy, approval_ids: []], filter_policy_by: [location: [], teams: [], employee_status: []])
        end
      end
    end
  end
end


