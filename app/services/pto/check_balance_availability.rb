module Pto
  class CheckBalanceAvailability

    def perform pto, balance_to_check, amount=nil
      return balance_available?(pto, balance_to_check, amount)
    end

    def remaining_balance pto, balance_to_check, amount=nil
      return balance_amount?(pto, balance_to_check, amount)
    end

    def remaining_balance_after_detuction pto
      assigned_policy = pto.user.assigned_pto_policies.find_by_pto_policy_id(pto.pto_policy_id)
      begin_date = pto.partner_pto_requests.present? ? pto.calculate_begin_date : pto.begin_date
      res = Pto::PtoEstimateBalance.new(assigned_policy, begin_date, pto.pto_policy.company).perform
      total_balance = res[:estimated_balance]
      carryover_balance = res[:carryover_balance]
      return {balance: total_balance, carryover_balance: carryover_balance}
    end

    private

    def balance_amount? pto, balance_to_check, amount
      pto_policy = pto.pto_policy
      @current_date = pto_policy.company.time.to_date
      assigned_policy = pto.user.assigned_pto_policies.find_by_pto_policy_id(pto.pto_policy_id)
      return assigned_policy.total_balance if pto_policy.unlimited_policy || is_of_past_period?(pto, pto_policy)
      return false if assigned_policy.nil?
      assigned_policy.balance += amount if amount
      begin_date = pto.begin_date < pto.pto_policy.company.time.to_date ? pto.pto_policy.company.time.to_date : pto.begin_date
      res = Pto::PtoEstimateBalance.new(assigned_policy, begin_date, pto.pto_policy.company, nil, pto.id).get_policy_balance_for_pto
      assigned_policy.balance = res[:balance]
      assigned_policy.carryover_balance = res[:carryover_balance]
      updated_balances = pto.get_balance_after_deduction(assigned_policy, balance_to_check)
      assigned_policy.balance = updated_balances[:new_balance]
      assigned_policy.carryover_balance = updated_balances[:new_carryover_balance]
      return {balance: assigned_policy.total_balance, carryover_balance: assigned_policy.carryover_balance}
    end

    def balance_available? pto, balance_to_check, amount
      pto_policy = pto.pto_policy
      @current_date = pto_policy.company.time.to_date
      return true if pto_policy.unlimited_policy || is_of_past_period?(pto, pto_policy)
      assigned_policy = pto.user.assigned_pto_policies.find_by_pto_policy_id(pto.pto_policy_id)
      return true unless assigned_policy.present?
      assigned_policy.balance += amount if amount
      if is_historical?(pto) || future_pto?(pto)
        return is_pto_valid? pto, assigned_policy, balance_to_check
      end
      return true
    end

    def is_historical? pto
      pto.begin_date <= @current_date && !is_of_past_period?(pto, pto.pto_policy)
    end

    def is_of_past_period? pto, pto_policy
      pto.begin_date < pto.get_renewal_date(pto_policy.company.time.to_date) - 1.year
    end

    def future_pto? pto
      pto.begin_date > @current_date
    end

    def is_pto_valid? pto, assigned_policy, balance_to_check
      begin_date = pto.begin_date < pto.pto_policy.company.time.to_date ? pto.pto_policy.company.time.to_date : pto.begin_date
      res = Pto::PtoEstimateBalance.new(assigned_policy, begin_date, pto.pto_policy.company, nil, pto.id).get_policy_balance_for_pto
      return false if check_balance_limit(balance_to_check , res[:balance] + res[:carryover_balance], pto.pto_policy)
      assigned_policy.balance = res[:balance]
      assigned_policy.carryover_balance = res[:carryover_balance]
      updated_balances = pto.get_balance_after_deduction(assigned_policy, balance_to_check)
      assigned_policy.balance = updated_balances[:new_balance]
      assigned_policy.carryover_balance = updated_balances[:new_carryover_balance]
      return true if does_not_affect_future_ptos(pto, assigned_policy, begin_date)
      return false
    end
    
    def does_not_affect_future_ptos pto, assigned_policy, date
      balance = assigned_policy.balance
      carryover_balance = assigned_policy.carryover_balance
      assigned_policy.pto_requests.where('begin_date > ?', date).where(status: [PtoRequest.statuses["pending"], PtoRequest.statuses["approved"]]).where.not(id: pto.id).order('begin_date asc').each do |pto_request|
        set_policy_balance(balance, carryover_balance, assigned_policy)
        res = Pto::PtoEstimateBalance.new(assigned_policy, pto_request.begin_date, pto_request.pto_policy.company, date, pto.id).get_policy_balance_for_pto
        return false if check_balance_negative_limit((res[:balance] + res[:carryover_balance]) , pto.pto_policy )
      end
      return true
    end

    def check_balance_limit balance_to_check, estimated, policy
      if policy.can_obtain_negative_balance 
        return (estimated - balance_to_check) < (policy.maximum_negative_amount * -1)
      else
        return balance_to_check > estimated
      end
    end

    def check_balance_negative_limit estimated, policy
      if policy.can_obtain_negative_balance 
        return estimated  < (policy.maximum_negative_amount * -1)
      else
        return estimated < 0
      end
    end
    
    def set_policy_balance balance, carryover_balance, assigned_policy
      assigned_policy.balance = balance
      assigned_policy.carryover_balance = carryover_balance
    end
  end
end
