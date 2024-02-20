module Pto
  class RenewPtoPolicies 
    
    def perform (company_id)
      @company = Company.find(company_id)
      @company_date = @company.time.to_date
      policies = AssignedPtoPolicy.joins(:user,:pto_policy).where('pto_policies.company_id = ? AND pto_policies.unlimited_policy = false AND pto_policies.is_enabled = true', company_id)
      unused_timeoff = "AND pto_policies.carry_over_unused_timeoff ="
      balance = "AND assigned_pto_policies.balance"
      renewal_time = "pto_policies.accrual_renewal_time="
      renewal_date = "extract(day  from pto_policies.accrual_renewal_date) = ? AND extract(month from pto_policies.accrual_renewal_date)= ?"
      max_accrual_query = unused_timeoff + "true AND pto_policies.has_maximum_carry_over_amount = true "+balance+" > 0"
      no_max_accrual_query = unused_timeoff + "true AND pto_policies.has_maximum_carry_over_amount = false "
      no_carry_over_query = unused_timeoff + "false "+balance+" > 0"
      no_carry_over_negative_query = " AND pto_policies.can_obtain_negative_balance = true AND pto_policies.carry_over_negative_balance = false "+balance+" < 0"
      carry_over_negative_query =  " AND pto_policies.can_obtain_negative_balance = true AND pto_policies.carry_over_negative_balance = true "+balance+" < 0"

      if @company_date == @company_date.beginning_of_year
        main_query = "("+renewal_time+" 1 OR ("+renewal_time+" 2 AND "+renewal_date+")) "
        execute_carryover_changes policies, main_query, max_accrual_query, no_carry_over_query, no_carry_over_negative_query, no_max_accrual_query, carry_over_negative_query

      else
        main_query = renewal_date
        execute_carryover_changes policies, main_query, max_accrual_query, no_carry_over_query, no_carry_over_negative_query, no_max_accrual_query, carry_over_negative_query
        
      end
      main_query = "extract(day  from users.start_date) = ? AND extract(month from users.start_date)= ? AND "+renewal_time+" 0"
      execute_carryover_changes policies, main_query, max_accrual_query, no_carry_over_query, no_carry_over_negative_query, no_max_accrual_query, carry_over_negative_query
      accrue_balance_for_yearly_policy policies.where("(pto_policies.accrual_frequency = 5 AND assigned_pto_policies.is_balance_calculated_before = true) AND (("+ main_query+") OR (("+renewal_time+" 1 OR "+renewal_time+" 2) AND "+renewal_date+"))", @company_date.day, @company_date.month, @company_date.day, @company_date.month)
    end

    def execute_carryover_changes policies, main_query, max_accrual_query, no_carry_over_query, no_carry_over_negative_query, no_max_accrual_query, carry_over_negative_query
      run_query policies, main_query, max_accrual_query , "max"
      run_query policies, main_query, no_carry_over_query , "reset"
      run_query policies, main_query, no_carry_over_negative_query , "reset"
      run_query policies, main_query, no_max_accrual_query , "unchanged"
      run_query policies, main_query, carry_over_negative_query , "unchanged"
    end

    def run_query policies, main_query, sub_query, type
      assigned_pto_policies = policies.where( main_query + sub_query, @company_date.day, @company_date.month)
      set_balance assigned_pto_policies, type if assigned_pto_policies.count > 0
    end

    def set_balance assigned_pto_policies, type
      assigned_pto_policies.try(:each) do |assigned_policy|
        begin
          is_balance_negative = false
          if type == "max"
            if assigned_policy.total_balance >= (assigned_policy.pto_policy.maximum_carry_over_amount * assigned_policy.pto_policy.working_hours)
              amount_adjusted = assigned_policy.total_balance - (assigned_policy.pto_policy.maximum_carry_over_amount * assigned_policy.pto_policy.working_hours)
              assigned_policy.carryover_balance = (assigned_policy.pto_policy.maximum_carry_over_amount * assigned_policy.pto_policy.working_hours)
              create_log(assigned_policy, amount_adjusted)
            else
              assigned_policy.carryover_balance = assigned_policy.balance + assigned_policy.carryover_balance if assigned_policy.balance.positive?
              is_balance_negative = true if !assigned_policy.balance.positive?
            end
          elsif type == "unchanged"
            assigned_policy.carryover_balance = assigned_policy.carryover_balance + assigned_policy.balance if assigned_policy.balance.positive?
            is_balance_negative = true if !assigned_policy.balance.positive?
          else
            assigned_policy.carryover_balance = assigned_policy.carryover_balance
            create_log assigned_policy, assigned_policy.balance
          end
          assigned_policy.balance = 0 if !is_balance_negative
          assigned_policy.initial_carryover_balance = assigned_policy.carryover_balance
          save_policy assigned_policy
        rescue Exception=>e
          LoggingService::GeneralLogging.new.create(@company, 'Renew Policies', {result: "Failed to renew assigned_pto_policy with id #{assigned_policy.id}", error: e.message}, 'PTO')           
        end
      end

    end

    def create_log assigned_policy, amount_adjusted
      if amount_adjusted.positive?
        assigned_policy.pto_balance_audit_logs.create(balance_used: amount_adjusted, balance_added: 0,  balance: assigned_policy.carryover_balance, description: "Policy Renewed", balance_updated_at: @company_date, user_id: assigned_policy.user_id)
      else
        assigned_policy.pto_balance_audit_logs.create(balance_used: 0, balance_added: amount_adjusted.abs,  balance: assigned_policy.carryover_balance, description: "Policy Renewed", balance_updated_at: @company_date, user_id: assigned_policy.user_id)
      end
    end

    def save_policy assigned_policy
      assigned_policy.save!
    end

    def accrue_balance_for_yearly_policy assigned_policies
      Pto::ManagePtoBalances.new(0, @company, true).add_balance_to_individual_assigned_policies(assigned_policies) if assigned_policies.count > 0
    end
  end
end
