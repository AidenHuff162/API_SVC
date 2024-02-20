module PtoPolicySerializer
  class Wizard < ActiveModel::Serializer
    attributes :id, :name, :policy_type, :for_all_employees, :icon, :filter_policy_by, :unlimited_policy, :accrual_rate_amount, :accrual_rate_unit, :rate_acquisition_period, :accrual_frequency,
               :has_max_accrual_amount, :max_accrual_amount, :allocate_accruals_at, :start_of_accrual_period, :accrual_period_start_date,
               :accrual_renewal_time, :accrual_renewal_date, :first_accrual_method, :carry_over_unused_timeoff, :has_maximum_carry_over_amount,
               :maximum_carry_over_amount, :can_obtain_negative_balance, :carry_over_negative_balance, :manager_approval, :auto_approval, :tracking_unit, :expire_unused_carryover_balance, :carryover_amount_expiry_date, :working_hours,
               :half_day_enabled, :working_days, :unlimited_type_title, :assign_manually, :days_to_wait_until_auto_actionable, :has_maximum_increment,
               :has_minimum_increment, :minimum_increment_amount, :maximum_increment_amount, :maximum_negative_amount, :approval_chains, :display_detail, :is_paid_leave, :show_balance_on_pay_slip,
               :has_stop_accrual_date, :stop_accrual_date

    has_many :policy_tenureships , serializer: PolicyTenureshipSerializer::Basic
    def accrual_renewal_date
      if object.accrual_renewal_date.present?
        object.accrual_renewal_date.strftime("%Y-%m-%d")
      else
        nil
      end
    end

    def carryover_amount_expiry_date
      if object.carryover_amount_expiry_date.present?
        object.carryover_amount_expiry_date.strftime("%Y-%m-%d")
      else
        nil
      end
    end

    def approval_chains
      ActiveModelSerializers::SerializableResource.new(object.approval_chains.order(id: :asc), each_serializer: ApprovalChainSerializer::Basic, company: object.company_id)
    end
  end
end
